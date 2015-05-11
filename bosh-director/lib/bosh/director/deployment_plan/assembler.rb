module Bosh::Director
  # DeploymentPlan::Assembler is used to populate deployment plan with information
  # about existing deployment and information from director DB
  class DeploymentPlan::Assembler
    include LockHelper
    include IpUtil

    def initialize(deployment_plan, stemcell_manager, cloud, blobstore, logger, event_log)
      @deployment_plan = deployment_plan
      @cloud = cloud
      @logger = logger
      @event_log = event_log
      @stemcell_manager = stemcell_manager
      @blobstore = blobstore
    end

    # Binds release DB record(s) to a plan
    # @return [void]
    def bind_releases
      releases = @deployment_plan.releases
      with_release_locks(releases.map(&:name)) do
        releases.each do |release|
          release.bind_model
        end
      end
    end

    # Binds information about existing deployment to a plan
    # @return [void]
    def bind_existing_deployment
      lock = Mutex.new
      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        @deployment_plan.vms.each do |vm_model|
          pool.process do
            with_thread_name("bind_existing_deployment(#{vm_model.agent_id})") do
              bind_existing_vm(vm_model, lock)
            end
          end
        end
      end
    end

    # Queries agent for VM state and updates deployment plan accordingly
    # @param [Models::Vm] vm_model VM database model
    # @param [Mutex] lock Lock to hold on to while updating deployment plan
    def bind_existing_vm(vm_model, lock)
      state = get_state(vm_model)
      lock.synchronize do
        @logger.debug('Processing VM network reservations')
        reservations = get_network_reservations(state)

        instance = vm_model.instance
        if instance
          bind_instance(instance, state, reservations)
        else
          resource_pool_name = state['resource_pool']['name']
          resource_pool = @deployment_plan.resource_pool(resource_pool_name)
          if resource_pool
            @logger.debug("Binding VM to resource pool '#{resource_pool_name}'")
            bind_idle_vm(vm_model, resource_pool, state, reservations)
          else
            @logger.debug("Resource pool '#{resource_pool_name}' does not exist, marking VM for deletion")
            @deployment_plan.delete_vm(vm_model)
          end
        end
        @logger.debug('Finished processing VM network reservations')
      end
    end

    # Binds idle VM to a resource pool with a proper network reservation
    # @param [Models::Vm] vm_model VM DB model
    # @param [DeploymentPlan::ResourcePool] resource_pool Resource pool
    # @param [Hash] state VM state according to its agent
    # @param [Hash] reservations Network reservations
    def bind_idle_vm(vm_model, resource_pool, state, reservations)
      if reservations.any? { |network_name, reservation| reservation.static? }
        @logger.debug("Releasing all network reservations for VM `#{vm_model.cid}'")
        reservations.each do |network_name, reservation|
          @logger.debug("Releasing #{reservation.type} network reservation `#{network_name}' for VM `#{vm_model.cid}'")
          @deployment_plan.network(network_name).release(reservation)
        end

        @logger.debug("Deleting VM `#{vm_model.cid}' with static network reservation")
        @deployment_plan.delete_vm(vm_model)
        return
      end

      @logger.debug("Adding VM `#{vm_model.cid}' to resource pool `#{resource_pool.name}'")
      idle_vm = resource_pool.add_idle_vm
      idle_vm.model = vm_model
      idle_vm.current_state = state

      network_name = resource_pool.network.name
      reservation = reservations[network_name]
      if reservation
        @logger.debug("Using existing `#{reservation.type}' " +
          "network reservation of `#{reservation.ip}' for VM `#{vm_model.cid}'")
        idle_vm.use_reservation(reservation)
      else
        @logger.debug("No network reservation for VM `#{vm_model.cid}'")
      end
    end

    # @param [Models::Instance] instance_model Instance model
    # @param [Hash] state Instance state according to agent
    # @param [Hash] reservations Instance network reservations
    def bind_instance(instance_model, state, reservations)
      @logger.debug('Binding instance VM')

      # Update instance, if we are renaming a job.
      if @deployment_plan.rename_in_progress?
        old_name = @deployment_plan.job_rename['old_name']
        new_name = @deployment_plan.job_rename['new_name']

        if instance_model.job == old_name
          @logger.info("Renaming `#{old_name}' to `#{new_name}'")
          instance_model.update(:job => new_name)
        end
      end

      instance_name = "#{instance_model.job}/#{instance_model.index}"

      job = @deployment_plan.job(instance_model.job)
      unless job
        @logger.debug("Job `#{instance_model.job}' not found, marking for deletion")
        @deployment_plan.delete_instance(instance_model)
        return
      end

      instance = job.instance(instance_model.index)
      unless instance
        @logger.debug("Job instance `#{instance_name}' not found, marking for deletion")
        @deployment_plan.delete_instance(instance_model)
        return
      end

      @logger.debug("Found existing job instance `#{instance_name}'")
      instance.bind_existing_instance(instance_model, state, reservations)
    end

    def get_network_reservations(state)
      reservations = {}
      state['networks'].each do |name, network_config|
        network = @deployment_plan.network(name)
        if network
          reservation = NetworkReservation.new(:ip => network_config['ip'])
          network.reserve(reservation)
          reservations[name] = reservation if reservation.reserved?
        end
      end
      reservations
    end

    def get_state(vm_model)
      @logger.debug("Requesting current VM state for: #{vm_model.agent_id}")
      agent = AgentClient.with_defaults(vm_model.agent_id)
      state = agent.get_state

      @logger.debug("Received VM state: #{state.pretty_inspect}")
      verify_state(vm_model, state)
      @logger.debug('Verified VM state')

      migrate_legacy_state(vm_model, state)
      state.delete('release')
      if state.include?('job')
        state['job'].delete('release')
      end
      state
    end

    def verify_state(vm_model, state)
      instance = vm_model.instance

      if instance && instance.deployment_id != vm_model.deployment_id
        # Both VM and instance should reference same deployment
        raise VmInstanceOutOfSync,
              "VM `#{vm_model.cid}' and instance " +
              "`#{instance.job}/#{instance.index}' " +
              "don't belong to the same deployment"
      end

      unless state.kind_of?(Hash)
        @logger.error("Invalid state for `#{vm_model.cid}': #{state.pretty_inspect}")
        raise AgentInvalidStateFormat,
              "VM `#{vm_model.cid}' returns invalid state: " +
              "expected Hash, got #{state.class}"
      end

      actual_deployment_name = state['deployment']
      expected_deployment_name = @deployment_plan.name

      if actual_deployment_name != expected_deployment_name
        raise AgentWrongDeployment,
              "VM `#{vm_model.cid}' is out of sync: " +
                'expected to be a part of deployment ' +
              "`#{expected_deployment_name}' " +
                'but is actually a part of deployment ' +
              "`#{actual_deployment_name}'"
      end

      actual_job = state['job'].is_a?(Hash) ? state['job']['name'] : nil
      actual_index = state['index']

      if instance.nil? && !actual_job.nil?
        raise AgentUnexpectedJob,
              "VM `#{vm_model.cid}' is out of sync: " +
              "it reports itself as `#{actual_job}/#{actual_index}' but " +
                'there is no instance reference in DB'
      end

      if instance &&
        (instance.job != actual_job || instance.index != actual_index)
        # Check if we are resuming a previously unfinished rename
        if actual_job == @deployment_plan.job_rename['old_name'] &&
           instance.job == @deployment_plan.job_rename['new_name'] &&
           instance.index == actual_index

          # Rename already happened in the DB but then something happened
          # and agent has never been updated.
          unless @deployment_plan.job_rename['force']
            raise AgentRenameInProgress,
                  "Found a job `#{actual_job}' that seems to be " +
                  "in the middle of a rename to `#{instance.job}'. " +
                  "Run 'rename' again with '--force' to proceed."
          end
        else
          raise AgentJobMismatch,
                "VM `#{vm_model.cid}' is out of sync: " +
                "it reports itself as `#{actual_job}/#{actual_index}' but " +
                "according to DB it is `#{instance.job}/#{instance.index}'"
        end
      end
    end

    def migrate_legacy_state(vm_model, state)
      # Persisting apply spec for VMs that were introduced before we started
      # persisting it on apply itself (this is for cloudcheck purposes only)
      if vm_model.apply_spec.nil?
        # The assumption is that apply_spec <=> VM state
        vm_model.update(:apply_spec => state)
      end

      instance = vm_model.instance
      if instance
        disk_size = state['persistent_disk'].to_i
        persistent_disk = instance.persistent_disk

        # This is to support legacy deployments where we did not have
        # the disk_size specified.
        if disk_size != 0 && persistent_disk && persistent_disk.size == 0
          persistent_disk.update(:size => disk_size)
        end
      end
    end

    # Takes a look at the current state of all resource pools in the deployment
    # and schedules adding any new VMs if needed. VMs are NOT created at this
    # stage, only data structures are being allocated. {ResourcePoolUpdater}
    # will later perform actual changes based on this data.
    # @return [void]
    def bind_resource_pools
      @deployment_plan.resource_pools.each do |resource_pool|
        resource_pool.process_idle_vms
      end
    end

    # Looks at every job instance in the deployment plan and binds it to the
    # instance database model (idle VM is also created in the appropriate
    # resource pool if necessary)
    # @return [void]
    def bind_unallocated_vms
      @deployment_plan.jobs_starting_on_deploy.each(&:bind_unallocated_vms)
    end

    def bind_instance_networks
      @deployment_plan.jobs_starting_on_deploy.each(&:bind_instance_networks)
    end

    # Binds template models for each release spec in the deployment plan
    # @return [void]
    def bind_templates
      @deployment_plan.releases.each do |release|
        release.bind_templates
      end

      @deployment_plan.jobs.each do |job|
        job.validate_package_names_do_not_collide!
      end
    end

    # Binds properties for all templates in the deployment
    # @return [void]
    def bind_properties
      @deployment_plan.jobs.each do |job|
        job.bind_properties
      end
    end

    # Binds stemcell model for each stemcell spec in each resource pool in
    # the deployment plan
    # @return [void]
    def bind_stemcells
      @deployment_plan.resource_pools.each do |resource_pool|
        stemcell = resource_pool.stemcell

        if stemcell.nil?
          raise DirectorError,
                "Stemcell not bound for resource pool `#{resource_pool.name}'"
        end

        stemcell.bind_model
      end
    end

    def bind_dns
      binder = DeploymentPlan::DnsBinder.new(@deployment_plan)
      binder.bind_deployment
    end
  end
end
