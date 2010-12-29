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
      update_resource_pool
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
      drain_time = agent.drain
      sleep(drain_time)
      agent.stop
    end

    def update_resource_pool
      if @instance_spec.resource_pool_changed?
        if @instance.disk_cid
          @cloud.detach_disk(@vm.cid, @instance.disk_cid)
        end

        @cloud.delete_vm(@vm.cid)
        @instance.vm = nil
        @instance.save!
        @vm.delete

        stemcell = @resource_pool_spec.stemcell.stemcell

        agent_id = generate_agent_id
        vm_cid = @cloud.create_vm(agent_id, stemcell.cid, @resource_pool_spec.cloud_properties,
                                 @instance_spec.network_settings, @instance.disk_cid)

        @vm = Models::Vm.new
        @vm.deployment = @deployment_plan.deployment
        @vm.agent_id = agent_id
        @vm.cid = vm_cid
        @vm.save!
        @instance.vm = @vm
        @instance.save!

        if @instance.disk_cid
          @cloud.attach_disk(@vm.cid, @instance.disk_cid)
        end

        agent.wait_until_ready

        state = {
          "deployment" => @deployment_plan.name,
          "networks" => @instance_spec.network_settings,
          "resource_pool" => @job_spec.resource_pool.properties,
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

          if old_disk_cid
            task = agent.migrate_disk(@job_spec.persistent_disk)
            while task["state"] == "running"
              sleep(1.0)
              task = agent.get_task(task["agent_task_id"])
            end
          end
        end

        @instance.disk_cid = disk_cid
        @instance.save!

        if old_disk_cid
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
        agent.commit_network_change(network_settings)
      end
    end

    def apply_deployment
      task = agent.apply({
        "deployment" => @deployment_plan.name,
        "job" => @job_spec.name,
        "index" => @instance_spec.index,
        "networks" => @instance_spec.network_settings,
        "resource_pool" => @job_spec.resource_pool.properties,
        "packages" => @job_spec.package_spec,
        "persistent_disk" => @job_spec.persistent_disk,
        "configuration_hash" => @instance_spec.configuration_hash,
        "properties" => @job_spec.properties
      })
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