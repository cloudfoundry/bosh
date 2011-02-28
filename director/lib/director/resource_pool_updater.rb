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
      extra_vms = -@resource_pool.unallocated_vms
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
      @logger.info("Deleting outdated VMs")
      @resource_pool.idle_vms.each do |idle_vm|
        if idle_vm.vm && idle_vm.changed?
          vm_cid = idle_vm.vm.cid
          @logger.info("Deleting outdated VM: #{vm_cid}")
          @pool.process do
            @cloud.delete_vm(vm_cid)
            vm = idle_vm.vm
            idle_vm.vm = nil
            idle_vm.current_state = nil
            vm.destroy
          end
        end
      end
      @pool.wait
    end

    def create_missing_vms
      @logger.info("Creating missing VMs")
      @resource_pool.idle_vms.each do |idle_vm|
        unless idle_vm.vm
          @pool.process do
            begin
              # TODO: create VM model and save the agent_id before creating the VM in the cloud
              # TODO: define NotCreated vs PartiallyCreated error

              agent_id = generate_agent_id
              vm_cid = @cloud.create_vm(agent_id, @resource_pool.stemcell.stemcell.cid, @resource_pool.cloud_properties,
                                        idle_vm.network_settings)

              vm = Models::Vm.new
              vm.deployment = @resource_pool.deployment.deployment
              vm.agent_id = agent_id
              vm.cid = vm_cid
              vm.save

              # TODO: delete the VM if it wasn't saved

              agent = AgentClient.new(vm.agent_id)
              agent.wait_until_ready

              task = agent.apply({
                "deployment" => @resource_pool.deployment.name,
                "resource_pool" => @resource_pool.spec,
                "networks" => idle_vm.network_settings
              })
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
                vm.destroy if vm.id
              rescue Exception
                @logger.info("Could not cleanup VM: #{vm_cid}")
              end

              raise e
            end
          end
        end
      end
      @pool.wait
    end

    def generate_agent_id
      UUIDTools::UUID.random_create.to_s
    end

  end

end