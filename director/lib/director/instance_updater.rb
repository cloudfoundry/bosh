module Bosh::Director
  class InstanceUpdater
    MAX_ATTACH_DISK_TRIES = 3

    # @params instance_spec Bosh::DeploymentPlan::InstanceSpec
    def initialize(instance_spec)
      @cloud = Config.cloud
      @logger = Config.logger

      @instance_spec = instance_spec
      @job_spec      = instance_spec.job

      @instance     = @instance_spec.instance
      @target_state = @instance_spec.state

      @deployment_plan    = @job_spec.deployment
      @resource_pool_spec = @job_spec.resource_pool
      @update_config      = @job_spec.update

      @vm = @instance.vm
    end

    def update(options = {})
      stop

      if @target_state == "detached"
        detach_disk
        delete_vm
        @resource_pool_spec.add_idle_vm
        return
      end

      update_resource_pool
      update_persistent_disk
      update_networks

      apply_state(@instance_spec.spec)

      if @target_state == "started"
        agent.start
      end

      watch_time = options[:canary] ? @update_config.canary_watch_time : @update_config.update_watch_time
      sleep(watch_time / 1000)

      current_state = agent.get_state

      if @target_state == "started" && current_state["job_state"] != "running"
        raise "updated instance not healthy"
      elsif @target_state == "stopped" && current_state["job_state"] == "running"
        raise "instance is still running despite the stop command"
      end
    end

    def stop
      if @instance_spec.resource_pool_changed? || @instance_spec.persistent_disk_changed? ||
          @instance_spec.networks_changed? || @target_state == "stopped" || @target_state == "detached"
        drain_time = agent.drain("shutdown")
      else
        drain_time = agent.drain("update", @instance_spec.spec)
      end
      sleep(drain_time)
      agent.stop
    end

    def detach_disk
      return unless @instance_spec.disk_currently_attached?

      if @instance.disk_cid.nil?
        raise "Error while detaching disk: unknown disk attached to instance"
      end

      task = agent.unmount_disk(@instance.disk_cid)
      while task["state"] == "running"
        sleep(1.0)
        task = agent.get_task(task["agent_task_id"])
      end
      @cloud.detach_disk(@vm.cid, @instance.disk_cid)
    end

    def attach_disk
      return if @instance.disk_cid.nil?

      @cloud.attach_disk(@vm.cid, @instance.disk_cid)
      task = agent.mount_disk(@instance.disk_cid)
      while task["state"] == "running"
        sleep(1.0)
        task = agent.get_task(task["agent_task_id"])
      end
    end

    def delete_vm
      @cloud.delete_vm(@vm.cid)

      @instance.db.transaction do
        @instance.vm = nil
        @instance.save
        @vm.destroy
      end
    end

    def create_vm(extra_disk_id)
      stemcell = @resource_pool_spec.stemcell.stemcell
      agent_id = generate_agent_id

      @vm = Models::Vm.new
      @vm.deployment = @deployment_plan.deployment
      @vm.agent_id = agent_id
      @vm.save

      disks = [@instance.disk_cid, extra_disk_id].compact

      @vm.cid = @cloud.create_vm(agent_id, stemcell.cid, @resource_pool_spec.cloud_properties,
                                 @instance_spec.network_settings, disks, @resource_pool_spec.env)

      @instance.db.transaction do
        @vm.save
        @instance.vm = @vm
        @instance.save
      end

      # TODO: delete the VM if it wasn't saved
      agent.wait_until_ready
    end

    def apply_state(state)
      task = agent.apply(state)
      while task["state"] == "running"
        sleep(1.0)
        task = agent.get_task(task["agent_task_id"])
      end
    end

    def update_resource_pool(new_disk_cid = nil)
      return unless @instance_spec.resource_pool_changed? || new_disk_cid

      detach_disk
      num_retries = 0
      begin
        delete_vm
        create_vm(new_disk_cid)
        attach_disk
      rescue NoDiskSpace => e
        if e.ok_to_retry && num_retries < MAX_ATTACH_DISK_TRIES
          num_retries += 1
          @logger.warn("Retrying attach disk operation #{num_retries}")
          retry
        end
        @logger.warn("Giving up on attach disk operation")
        e.ok_to_retry = false
        raise
      end

      state = {
        "deployment" => @deployment_plan.name,
        "networks" => @instance_spec.network_settings,
        "resource_pool" => @job_spec.resource_pool.spec,
      }

      if @instance_spec.disk_size > 0
        state["persistent_disk"] = @instance_spec.disk_size
      end

      apply_state(state)
      @instance_spec.current_state = agent.get_state
    end

    def attach_missing_disk
      if @instance.disk_cid && !@instance_spec.disk_currently_attached?
        attach_disk
      end
    rescue NoDiskSpace => e
      update_resource_pool(@instance.disk_cid)
    end

    def update_persistent_disk
      attach_missing_disk

      return unless @instance_spec.persistent_disk_changed?
      old_disk_cid = @instance.disk_cid

      if @job_spec.persistent_disk > 0
        disk_cid = @cloud.create_disk(@job_spec.persistent_disk, @vm.cid)
        begin
          @cloud.attach_disk(@vm.cid, disk_cid)
        rescue NoDiskSpace => e
          if e.ok_to_retry
            @logger.warn("Retrying attach disk operation after persistent disk update failed")
            # Recreate the vm
            update_resource_pool(disk_cid)
            begin
              @cloud.attach_disk(@vm.cid, disk_cid)
            rescue
              # Cleanup disk model entry
              @cloud.delete_disk(disk_cid)
              raise
            end
          else
            # Cleanup disk model entry
            @cloud.delete_disk(disk_cid)
            raise
          end
        end

        task = agent.mount_disk(disk_cid)
        while task["state"] == "running"
          sleep(1.0)
          task = agent.get_task(task["agent_task_id"])
        end

        if old_disk_cid
          task = agent.migrate_disk(old_disk_cid, disk_cid)
          while task["state"] == "running"
            sleep(1.0)
            task = agent.get_task(task["agent_task_id"])
          end
        end
      end

      @instance.disk_cid = disk_cid
      @instance.disk_size = @job_spec.persistent_disk
      @instance.save

      if old_disk_cid
        task = agent.unmount_disk(old_disk_cid)
        while task["state"] == "running"
          sleep(1.0)
          task = agent.get_task(task["agent_task_id"])
        end
        @cloud.detach_disk(@vm.cid, old_disk_cid)
        @cloud.delete_disk(old_disk_cid) if old_disk_cid
      end
    end

    def update_networks
      return unless @instance_spec.networks_changed?

      network_settings = @instance_spec.network_settings
      agent.prepare_network_change(network_settings)
      @cloud.configure_networks(@vm.cid, network_settings)
      agent.wait_until_ready
    end

    def agent
      if @agent && @agent.id == @vm.agent_id
        @agent
      else
        raise "agent id required to create an agent client" if @vm.agent_id.nil?
        @agent = AgentClient.new(@vm.agent_id)
      end
    end

    def generate_agent_id
      UUIDTools::UUID.random_create.to_s
    end

  end
end
