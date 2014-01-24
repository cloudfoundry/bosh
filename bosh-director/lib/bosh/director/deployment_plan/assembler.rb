module Bosh::Director
  # DeploymentPlan::Assembler is used to populate deployment plan with information
  # about existing deployment and information from director DB
  class DeploymentPlan::Assembler
    include DnsHelper
    include LockHelper
    include IpUtil

    # @param [DeploymentPlan] deployment_plan Deployment plan
    def initialize(deployment_plan)
      @deployment_plan = deployment_plan
      @cloud = Config.cloud
      @logger = Config.logger
      @event_log = Config.event_log
      @stemcell_manager = Api::StemcellManager.new
      @blobstore = App.instance.blobstores.blobstore
    end

    # Binds deployment DB record to a plan
    # @return [void]
    def bind_deployment
      @deployment_plan.bind_model
    end

    # Binds release DB record(s) to a plan
    # @return [void]
    def bind_releases
      with_release_locks(@deployment_plan) do
        @deployment_plan.releases.each do |release|
          release.bind_model
        end
      end
    end

    # Binds information about existing deployment to a plan
    # @return [void]
    def bind_existing_deployment
      lock = Mutex.new
      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        @deployment_plan.vms.each do |vm|
          pool.process do
            with_thread_name("bind_existing_deployment(#{vm.agent_id})") do
              bind_existing_vm(vm, lock)
            end
          end
        end
      end
    end

    # Queries agent for VM state and updates deployment plan accordingly
    # @param [Models::Vm] vm VM database model
    # @param [Mutex] lock Lock to hold on to while updating deployment plan
    def bind_existing_vm(vm, lock)
      state = get_state(vm)
      lock.synchronize do
        @logger.debug('Processing network reservations')
        reservations = get_network_reservations(state)

        instance = vm.instance
        if instance
          bind_instance(instance, state, reservations)
        else
          @logger.debug('Binding resource pool VM')
          resource_pool = @deployment_plan.resource_pool(
              state['resource_pool']['name'])
          if resource_pool
            bind_idle_vm(vm, resource_pool, state, reservations)
          else
            @logger.debug("Resource pool doesn't exist, marking for deletion")
            @deployment_plan.delete_vm(vm)
          end
        end
        @logger.debug('Finished binding VM')
      end
    end

    # Binds idle VM to a resource pool with a proper network reservation
    # @param [Models::Vm] vm VM DB model
    # @param [DeploymentPlan::ResourcePool] resource_pool Resource pool
    # @param [Hash] state VM state according to its agent
    # @param [Hash] reservations Network reservations
    def bind_idle_vm(vm, resource_pool, state, reservations)
      @logger.debug('Adding to resource pool')
      idle_vm = resource_pool.add_idle_vm
      idle_vm.vm = vm
      idle_vm.current_state = state

      reservation = reservations[resource_pool.network.name]
      if reservation
        if reservation.static?
          @logger.debug('Releasing static network reservation for ' +
                        "resource pool VM `#{vm.cid}'")
          resource_pool.network.release(reservation)
        else
          idle_vm.use_reservation(reservation)
        end
      else
        @logger.debug("No network reservation for VM `#{vm.cid}'")
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

      # Does the job instance exist in the new deployment?
      if (job = @deployment_plan.job(instance_model.job)) &&
         (instance = job.instance(instance_model.index))

        @logger.debug('Found job and instance spec')
        instance.use_model(instance_model)
        instance.current_state = state

        @logger.debug('Copying network reservations')
        instance.take_network_reservations(reservations)

        @logger.debug('Copying resource pool reservation')
        job.resource_pool.mark_active_vm
      else
        @logger.debug('Job/instance not found, marking for deletion')
        @deployment_plan.delete_instance(instance_model)
      end
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

    def get_state(vm)
      @logger.debug("Requesting current VM state for: #{vm.agent_id}")
      agent = AgentClient.with_defaults(vm.agent_id)
      state = agent.get_state

      @logger.debug("Received VM state: #{state.pretty_inspect}")
      verify_state(vm, state)
      @logger.debug('Verified VM state')

      migrate_legacy_state(vm, state)
      state.delete('release')
      if state.include?('job')
        state['job'].delete('release')
      end
      state
    end

    def verify_state(vm, state)
      instance = vm.instance

      if instance && instance.deployment_id != vm.deployment_id
        # Both VM and instance should reference same deployment
        raise VmInstanceOutOfSync,
              "VM `#{vm.cid}' and instance " +
              "`#{instance.job}/#{instance.index}' " +
              "don't belong to the same deployment"
      end

      unless state.kind_of?(Hash)
        @logger.error("Invalid state for `#{vm.cid}': #{state.pretty_inspect}")
        raise AgentInvalidStateFormat,
              "VM `#{vm.cid}' returns invalid state: " +
              "expected Hash, got #{state.class}"
      end

      actual_deployment_name = state['deployment']
      expected_deployment_name = @deployment_plan.name

      if actual_deployment_name != expected_deployment_name
        raise AgentWrongDeployment,
              "VM `#{vm.cid}' is out of sync: " +
                'expected to be a part of deployment ' +
              "`#{expected_deployment_name}' " +
                'but is actually a part of deployment ' +
              "`#{actual_deployment_name}'"
      end

      actual_job = state['job'].is_a?(Hash) ? state['job']['name'] : nil
      actual_index = state['index']

      if instance.nil? && !actual_job.nil?
        raise AgentUnexpectedJob,
              "VM `#{vm.cid}' is out of sync: " +
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
                "VM `#{vm.cid}' is out of sync: " +
                "it reports itself as `#{actual_job}/#{actual_index}' but " +
                "according to DB it is `#{instance.job}/#{instance.index}'"
        end
      end
    end

    def migrate_legacy_state(vm, state)
      # Persisting apply spec for VMs that were introduced before we started
      # persisting it on apply itself (this is for cloudcheck purposes only)
      if vm.apply_spec.nil?
        # The assumption is that apply_spec <=> VM state
        vm.update(:apply_spec => state)
      end

      instance = vm.instance
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
      @deployment_plan.jobs.each do |job|
        job.instances.each do |instance|
          instance.bind_unallocated_vm
          # Now that we know every VM has been allocated and instance models are
          # bound, we can sync the state.
          instance.sync_state_with_db
        end
      end
    end

    def bind_instance_networks
      @deployment_plan.jobs.each do |job|
        job.instances.each do |instance|
          instance.network_reservations.each do |name, reservation|
            unless reservation.reserved?
              network = @deployment_plan.network(name)
              network.reserve!(reservation, "`#{job.name}/#{instance.index}'")
            end
          end
        end
      end
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

    # Calculates configuration checksums for all jobs in this deployment plan
    # @return [void]
    def bind_configuration
      @deployment_plan.jobs.each do |job|
        JobRenderer.new(job).render_job_instances(@blobstore)
      end
    end

    def bind_dns
      domain = Models::Dns::Domain.find_or_create(:name => dns_domain_name,
                                                  :type => 'NATIVE')
      @deployment_plan.dns_domain = domain

      soa_record = Models::Dns::Record.find_or_create(:domain_id => domain.id,
                                                      :name => dns_domain_name,
                                                      :type => 'SOA')
      soa_record.content = SOA
      soa_record.ttl = 300
      soa_record.save

      # add NS record
      Models::Dns::Record.find_or_create(:domain_id => domain.id,
                                         :name => dns_domain_name,
                                         :type =>'NS', :ttl => TTL_4H,
                                         :content => dns_ns_record)
      # add A record for name server
      Models::Dns::Record.find_or_create(:domain_id => domain.id,
                                         :name => dns_ns_record,
                                         :type =>'A', :ttl => TTL_4H,
                                         :content => Config.dns['address'])
    end

    def bind_instance_vms
      unbound_instances = []

      @deployment_plan.jobs.each do |job|
        job.instances.each do |instance|
          # Don't allocate resource pool VMs to instances in detached state
          next if instance.state == 'detached'
          # Skip bound instances
          next if instance.model.vm
          unbound_instances << instance
        end
      end

      return if unbound_instances.empty?

      @event_log.begin_stage('Binding instance VMs', unbound_instances.size)

      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        unbound_instances.each do |instance|
          pool.process do
            bind_instance_vm(instance)
          end
        end
      end
    end

    # @param [DeploymentPlan::Instance]
    def bind_instance_vm(instance)
      @event_log.track("#{instance.job.name}/#{instance.index}") do
        idle_vm = instance.idle_vm

        # Apply the assignment to the VM
        agent = AgentClient.with_defaults(idle_vm.vm.agent_id)
        state = idle_vm.current_state
        state['job'] = instance.job.spec
        state['index'] = instance.index
        agent.apply(state)

        # Our assumption here is that director database access
        # is much less likely to fail than VM agent communication
        # so we only update database after we see a successful agent apply.
        # If database update fails subsequent deploy will try to
        # assign a new VM to this instance which is ok.
        idle_vm.vm.db.transaction do
          idle_vm.vm.update(:apply_spec => state)
          instance.model.update(:vm => idle_vm.vm)
        end
        instance.current_state = state
      end
    end

    def delete_unneeded_vms
      unneeded_vms = @deployment_plan.unneeded_vms
      if unneeded_vms.empty?
        @logger.info('No unneeded vms to delete')
        return
      end

      @event_log.begin_stage('Deleting unneeded VMs', unneeded_vms.size)
      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        unneeded_vms.each do |vm|
          pool.process do
            @event_log.track(vm.cid) do
              @logger.info("Delete unneeded VM #{vm.cid}")
              @cloud.delete_vm(vm.cid)
              vm.destroy
            end
          end
        end
      end
    end

    def delete_unneeded_instances
      unneeded_instances = @deployment_plan.unneeded_instances
      if unneeded_instances.empty?
        @logger.info('No unneeded instances to delete')
        return
      end

      event_log_stage = @event_log.begin_stage('Deleting unneeded instances', unneeded_instances.size)
      instance_deleter = InstanceDeleter.new(@deployment_plan)
      instance_deleter.delete_instances(unneeded_instances, event_log_stage)
      @logger.info('Deleted no longer needed instances')
    end
  end
end
