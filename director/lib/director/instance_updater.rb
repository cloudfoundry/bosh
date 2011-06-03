module Bosh::Director
  class InstanceUpdater

    def initialize(instance)
      @instance_spec = instance
      @cloud = Config.cloud
      @job_spec = instance.job
      @deployment_plan = @job_spec.deployment
      @resource_pool_spec = @job_spec.resource_pool
      @instance = @instance_spec.instance
      @vm = @instance.vm
    end

    def update(options = {})
      stop
      force = options[:force] || false
      update_resource_pool(force)
      update_persistent_disk
      update_networks
      apply_deployment

      update_config = @job_spec.update

      watch_time = options[:canary] ? update_config.canary_watch_time : update_config.update_watch_time
      sleep(watch_time / 1000)

      state = agent.get_state
      raise "updated instance not healthy" unless state["job_state"] == "running"
    end

    def stop
      if @instance_spec.resource_pool_changed? || @instance_spec.persistent_disk_changed? ||
          @instance_spec.networks_changed?
        drain_time = agent.drain("shutdown")
      else
        drain_time = agent.drain("update", @instance_spec.spec)
      end
      sleep(drain_time)
      agent.stop
    end

    def update_resource_pool(force)
      if @instance_spec.resource_pool_changed? || force
        if @instance.disk_cid
          task = agent.unmount_disk(@instance.disk_cid)
          while task["state"] == "running"
            sleep(1.0)
            task = agent.get_task(task["agent_task_id"])
          end
          @cloud.detach_disk(@vm.cid, @instance.disk_cid)
        end

        @cloud.delete_vm(@vm.cid)

        @instance.db.transaction do
          @instance.vm = nil
          @instance.save
          @vm.destroy
        end

        stemcell = @resource_pool_spec.stemcell.stemcell

        agent_id = generate_agent_id

        @vm = Models::Vm.new
        @vm.deployment = @deployment_plan.deployment
        @vm.agent_id = agent_id
        @vm.save

        @vm.cid = @cloud.create_vm(agent_id, stemcell.cid, @resource_pool_spec.cloud_properties,
                                   @instance_spec.network_settings, @instance.disk_cid,
                                   @resource_pool_spec.env)
        @instance.db.transaction do
          @vm.save
          @instance.vm = @vm
          @instance.save
        end

        # TODO: delete the VM if it wasn't saved

        agent.wait_until_ready

        if @instance.disk_cid
          @cloud.attach_disk(@vm.cid, @instance.disk_cid)
          task = agent.mount_disk(@instance.disk_cid)
          while task["state"] == "running"
            sleep(1.0)
            task = agent.get_task(task["agent_task_id"])
          end
        end

        state = {
          "deployment" => @deployment_plan.name,
          "networks" => @instance_spec.network_settings,
          "resource_pool" => @job_spec.resource_pool.spec,
          "persistent_disk" =>  @instance_spec.current_state["persistent_disk"]
        }
        state.delete("persistent_disk") if state["persistent_disk"].nil?

        task = agent.apply(state)
        while task["state"] == "running"
          sleep(1.0)
          task = agent.get_task(task["agent_task_id"])
        end

        @instance_spec.current_state = agent.get_state
      end
    end

    def update_persistent_disk
      if @instance_spec.persistent_disk_changed?
        disk_cid = nil
        old_disk_cid = @instance.disk_cid

        if @job_spec.persistent_disk > 0
          disk_cid = @cloud.create_disk(@job_spec.persistent_disk, @vm.cid)
          @cloud.attach_disk(@vm.cid, disk_cid)
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
    end

    def update_networks
      if @instance_spec.networks_changed?
        network_settings = @instance_spec.network_settings
        agent.prepare_network_change(network_settings)
        @cloud.configure_networks(@vm.cid, network_settings)
        agent.wait_until_ready
      end
    end

    def apply_deployment
      task = agent.apply(@instance_spec.spec)
      while task["state"] == "running"
        sleep(1.0)
        task = agent.get_task(task["agent_task_id"])
      end
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
