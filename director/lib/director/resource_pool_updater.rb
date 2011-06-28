module Bosh::Director

  class ResourcePoolUpdater

    def initialize(resource_pool)
      @resource_pool = resource_pool
      @cloud = Config.cloud
      @logger = Config.logger
    end

    def delete_extra_vms(thread_pool)
      extra_vms = @resource_pool.active_vms + @resource_pool.idle_vms.size + @resource_pool.allocated_vms.size -
          @resource_pool.size

      @logger.info("Deleting #{extra_vms} extra VMs")
      extra_vms.times do
        idle_vm = @resource_pool.idle_vms.shift
        vm_cid = idle_vm.vm.cid
        @logger.info("Deleting extra VM: #{vm_cid}")
        thread_pool.process do
          @cloud.delete_vm(vm_cid)
          idle_vm.vm.destroy
        end
      end
    end

    def delete_outdated_vms(thread_pool)
      counter = 0
      each_idle_vm do |idle_vm|
        if idle_vm.vm && idle_vm.changed?
          counter += 1
        end
      end

      @logger.info("Deleting #{counter} outdated VMs")
      each_idle_vm_with_index do |idle_vm, index|
        if idle_vm.vm && idle_vm.changed?
          vm_cid = idle_vm.vm.cid
          thread_pool.process do
            with_thread_name("delete_outdated_vm(#{@resource_pool.name}, #{index + 1}/#{counter})") do
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
    end

    def create_missing_vms(thread_pool)
      counter = 0
      each_idle_vm { |idle_vm| counter += 1 if (!idle_vm.vm) }

      @logger.info("Creating #{counter} missing VMs")
      each_idle_vm_with_index do |idle_vm, index|
        next if idle_vm.vm
        thread_pool.process do
          with_thread_name("create_missing_vm(#{@resource_pool.name}, #{index + 1}/#{counter})") do
            create_missing_vm(idle_vm)
          end
        end
      end
    end

    def each_idle_vm
      @resource_pool.allocated_vms.each { |idle_vm| yield idle_vm }
      @resource_pool.idle_vms.each { |idle_vm| yield idle_vm }
    end

    def each_idle_vm_with_index
      idx = 0
      @resource_pool.allocated_vms.each do |idle_vm|
        yield(idle_vm, idx)
        idx += 1
      end

      @resource_pool.idle_vms.each do |idle_vm|
        yield(idle_vm, idx)
        idx += 1
      end
    end

    def create_missing_vm(idle_vm)

      agent_id = generate_agent_id
      vm = Models::Vm.create(:deployment => @resource_pool.deployment.deployment, :agent_id => agent_id)
      vm_cid = @cloud.create_vm(agent_id, @resource_pool.stemcell.stemcell.cid,
                                @resource_pool.cloud_properties, idle_vm.network_settings, nil,
                                @resource_pool.env)
      # partially created vms should have an empty cid
      vm.cid = vm_cid
      vm.save

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
