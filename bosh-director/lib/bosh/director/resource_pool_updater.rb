module Bosh::Director
  class ResourcePoolUpdater
    def initialize(resource_pool)
      @resource_pool = resource_pool
      @cloud = Config.cloud
      @logger = Config.logger
      @event_log = Config.event_log
    end

    ##
    # Creates VMs that are considered missing from the deployment
    #
    # @param [ThreadPool] thread_pool Thread pool that will be used to
    #   parallelize the operation
    # @yield [VirtualMachine] filter for which missing VMs to create
    def create_missing_vms(thread_pool)
      counter = 0
      vms_to_process = []

      @resource_pool.vms.each do |vm|
        next if vm.model
        if !block_given? || yield(vm)
          counter += 1
          vms_to_process << vm
        end
      end

      @logger.info("Creating #{counter} missing VMs")
      vms_to_process.each_with_index do |vm, index|
        thread_pool.process do
          @event_log.track("#{@resource_pool.name}/#{index}") do
            with_thread_name("create_missing_vm(#{@resource_pool.name}, #{index}/#{counter})") do
              @logger.info("Creating missing VM")
              create_missing_vm(vm)
            end
          end
        end
      end
    end

    # Creates missing VMs that have bound instances
    # (as opposed to missing resource pool VMs)
    def create_bound_missing_vms(thread_pool)
      create_missing_vms(thread_pool) { |vm| !vm.bound_instance.nil? }
    end

    def create_missing_vm(vm)
      deployment = @resource_pool.deployment_plan.model
      stemcell = @resource_pool.stemcell.model

      vm_model = VmCreator.new.create(deployment, stemcell, @resource_pool.cloud_properties,
                                vm.network_settings, nil, @resource_pool.env)

      agent = AgentClient.with_defaults(vm_model.agent_id)
      agent.wait_until_ready
      agent.update_settings(Config.trusted_certs)
      vm_model.update(:trusted_certs_sha1 => Digest::SHA1.hexdigest(Config.trusted_certs))

      update_state(agent, vm_model, vm)

      vm.model = vm_model
      vm.current_state = agent.get_state
    rescue Exception => e
      @logger.info("Cleaning up the created VM due to an error: #{e}")
      begin
        @cloud.delete_vm(vm_model.cid) if vm_model && vm_model.cid
        vm_model.destroy if vm_model && vm_model.id
      rescue Exception
        @logger.info("Could not cleanup VM: #{vm_model.cid}") if vm_model
      end
      raise e
    end

    def update_state(agent, vm_model, vm)
      state = {
          "deployment" => @resource_pool.deployment_plan.name,
          "resource_pool" => @resource_pool.spec,
          "networks" => vm.network_settings
      }

      vm_model.update(:apply_spec => state)
      agent.apply(state)
    end

    # Deletes extra VMs in a resource pool
    # @param thread_pool Thread pool used to parallelize delete operations
    def delete_extra_vms(thread_pool)
      count = @resource_pool.extra_vm_count
      @logger.info("Deleting #{count} extra VMs")

      count.times do
        vm = @resource_pool.idle_vms.shift
        vm_cid = vm.model.cid

        thread_pool.process do
          @event_log.track("#{@resource_pool.name}/#{vm_cid}") do
            @logger.info("Deleting extra VM: #{vm_cid}")
            @cloud.delete_vm(vm_cid)
            vm.model.destroy
          end
        end
      end
    end

    def delete_outdated_idle_vms(thread_pool)
      count = outdated_idle_vm_count
      index = 0
      index_lock = Mutex.new

      @logger.info("Deleting #{count} outdated idle VMs")

      @resource_pool.idle_vms.each do |vm|
        next unless vm.model && vm.changed?
        vm_cid = vm.model.cid

        thread_pool.process do
          @event_log.track("#{@resource_pool.name}/#{vm_cid}") do
            index_lock.synchronize { index += 1 }

            with_thread_name("delete_outdated_vm(#{@resource_pool.name}, #{index - 1}/#{count})") do
              @logger.info("Deleting outdated VM: #{vm_cid}")
              @cloud.delete_vm(vm_cid)
              vm_model = vm.model
              vm.clean_vm
              vm_model.destroy
            end
          end
        end
      end
    end

    # Attempts to allocate a dynamic IP address for all idle VMs
    # (unless they already have one). This allows us to fail earlier
    # in case any of resource pools is not big enough to accommodate
    # those VMs.
    def reserve_networks
      @resource_pool.reserve_dynamic_networks
    end

    def generate_agent_id
      SecureRandom.uuid
    end

    def extra_vm_count
      @resource_pool.extra_vm_count
    end

    def outdated_idle_vm_count
      counter = 0
      @resource_pool.idle_vms.each do |vm|
        counter += 1 if vm.model && vm.changed?
      end
      counter
    end

    def missing_vm_count
      counter = 0
      @resource_pool.vms.each do |vm|
        next if vm.model
        counter += 1
      end
      counter
    end

    def bound_missing_vm_count
      counter = 0
      @resource_pool.vms.each do |vm|
        next if vm.model
        next if vm.bound_instance.nil?
        counter += 1
      end
      counter
    end
  end
end
