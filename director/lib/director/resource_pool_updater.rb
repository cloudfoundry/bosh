module Bosh::Director

  class ResourcePoolUpdater

    def initialize(resource_pool)
      @resource_pool = resource_pool
      @cloud = Config.cloud
      @logger = Config.logger
    end

    def update
      @pool = ThreadPool.new(:max_threads => 32)

      delete_extra_vms
      delete_outdated_vms
      create_missing_vms

      @pool.wait
    ensure
      @pool.shutdown
    end

    def delete_extra_vms
      extra_vms = @resource_pool.active_vms + @resource_pool.idle_vms.size + @resource_pool.allocated_vms.size -
          @resource_pool.size

      @logger.info("Deleting #{extra_vms} extra VMs")
      extra_vms.times do
        idle_vm = @resource_pool.idle_vms.shift
        vm_cid = idle_vm.vm.cid
        @logger.info("Deleting extra VM: #{vm_cid}")
        @pool.process do
          @cloud.delete_vm(vm_cid)
          idle_vm.vm.destroy
        end
      end
      @pool.wait
    end

    def delete_outdated_vms
      counter = 0
      @pool.pause
      each_idle_vm do |idle_vm|
        if idle_vm.vm && idle_vm.changed?
          index = counter += 1
          vm_cid = idle_vm.vm.cid
          @pool.process do
            with_thread_name("delete_outdated_vm(#{@resource_pool.name}, #{index}/#{counter})") do
              @logger.info("Deleting: #{vm_cid}")
              @cloud.delete_vm(vm_cid)
              vm = idle_vm.vm
              idle_vm.vm = nil
              idle_vm.current_state = nil
              vm.destroy
            end
          end
        end
      end
      @pool.resume
      @logger.info("Deleting #{counter} outdated VMs")
      @pool.wait
    end

    def create_missing_vms
      counter = 0
      @pool.pause
      each_idle_vm do |idle_vm|
        unless idle_vm.vm
          index = counter += 1
          @pool.process do
            with_thread_name("create_missing_vm(#{@resource_pool.name}, #{index}/#{counter})") do
              create_missing_vm(idle_vm)
            end
          end
        end
      end

      @pool.resume
      @logger.info("Creating #{counter} missing VMs")
      @pool.wait
    end

    def each_idle_vm
      @resource_pool.allocated_vms.each { |idle_vm| yield idle_vm }
      @resource_pool.idle_vms.each { |idle_vm| yield idle_vm }
    end

    def create_missing_vm(idle_vm)
      # TODO: create VM model and save the agent_id before creating the VM in the cloud
      # TODO: define NotCreated vs PartiallyCreated error

      agent_id = generate_agent_id
      vm_cid = @cloud.create_vm(agent_id, @resource_pool.stemcell.stemcell.cid,
                                @resource_pool.cloud_properties, idle_vm.network_settings, nil,
                                @resource_pool.env)

      vm = Models::Vm.create(:deployment => @resource_pool.deployment.deployment, :agent_id => agent_id, :cid => vm_cid)
      # TODO: delete the VM if it wasn't saved

      agent = AgentClient.new(vm.agent_id)
      agent.wait_until_ready

      state = {
        "deployment" => @resource_pool.deployment.name,
        "resource_pool" => @resource_pool.spec,
        "networks" => idle_vm.network_settings
      }

      # apply the instance state if it's already bound so we can recover if needed
      if idle_vm.bound_instance
        instance_spec = idle_vm.bound_instance.spec
        ["job", "index", "release"].each { |key| state[key] = instance_spec[key] }
      end

      task = agent.apply(state)
      while task["state"] == "running"
        sleep(1.0)
        task = agent.get_task(task["agent_task_id"])
      end

      idle_vm.vm = vm
      idle_vm.current_state = agent.get_state
    rescue Exception => e
      @logger.info("Cleaning up the created VM due to an error: #{e}")
      begin
        @cloud.delete_vm(vm_cid) if vm_cid
        vm.destroy if vm && vm.id
      rescue Exception
        @logger.info("Could not cleanup VM: #{vm_cid}")
      end

      raise e
    end

    def generate_agent_id
      UUIDTools::UUID.random_create.to_s
    end

  end

end