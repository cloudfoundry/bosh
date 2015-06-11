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
        vm.bound_instance.network_settings, nil, @resource_pool.env)

      agent = AgentClient.with_defaults(vm_model.agent_id)
      agent.wait_until_ready
      agent.update_settings(Config.trusted_certs)
      vm_model.update(:trusted_certs_sha1 => Digest::SHA1.hexdigest(Config.trusted_certs))

      update_state(agent, vm_model, vm)

      vm.model = vm_model
      vm.bound_instance.current_state = agent.get_state
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
          "networks" => vm.bound_instance.network_settings
      }

      vm_model.update(:apply_spec => state)
      agent.apply(state)
    end

    def generate_agent_id
      SecureRandom.uuid
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
