module Bosh::Director

  class ResourcePoolUpdater

    def initialize(resource_pool)
      @resource_pool = resource_pool
      @cloud = Config.cloud
    end

    def update
      @pool = ThreadPool.new(:min_threads => 1, :max_threads => 32)

      delete_extra_vms
      delete_outdated_vms
      create_missing_vms

      @pool.wait
    end

    def delete_extra_vms
      extra_vms = -@resource_pool.unallocated_vms
      extra_vms.times do
        idle_vm = @resource_pool.idle_vms.shift
        vm_cid = idle_vm.vm.cid
        @pool.process do
          @cloud.delete_vm(vm_cid)
        end
      end
    end

    def delete_outdated_vms
      @resource_pool.idle_vms.each do |idle_vm|
        if idle_vm.vm && idle_vm.changed?
          vm = idle_vm.vm
          vm_cid = vm.cid
          @pool.process do
            @cloud.delete_vm(vm_cid)
            idle_vm.vm = nil
            idle_vm.current_state = nil
          end
        end
      end
    end

    def create_missing_vms
      @resource_pool.idle_vms.each do |idle_vm|
        unless idle_vm.vm
          @pool.process do
            begin
              agent_id = generate_agent_id
              vm_cid = @cloud.create_vm(agent_id, @resource_pool.stemcell.stemcell.cid, @resource_pool.cloud_properties,
                                        idle_vm.network_settings)

              vm = Models::Vm.new
              vm.deployment = @resource_pool.deployment.deployment
              vm.agent_id = agent_id
              vm.cid = vm_cid
              vm.save!

              agent = AgentClient.new(vm.agent_id)
              agent.wait_until_ready
              idle_vm.vm = vm
              idle_vm.current_state = agent.get_state
            rescue => e
              @logger.info("Cleaning up the created VM due to an error: #{e}")
              begin
                @cloud.delete_vm(vm_cid) if vm_cid
              rescue
                @logger.info("Could not cleanup VM: #{vm_cid}")
              end

              begin
                vm.delete if vm.id
              rescue
                @logger.info("Could not delete VM model: #{vm.pretty_inspect}")
              end

              raise e
            end
          end
        end
      end
    end

    def generate_agent_id
      UUIDTools::UUID.random_create.to_s
    end

  end

end