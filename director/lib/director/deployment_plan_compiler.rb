# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlanCompiler
    include Bosh::Director::DnsHelper
    include Bosh::Director::IpUtil

    # @param [Bosh::Director::DeploymentPlan] deployment_plan Deployment plan
    def initialize(deployment_plan)
      @deployment_plan = deployment_plan
      @cloud = Config.cloud
      @logger = Config.logger
      @event_log = Config.event_log
      @stemcell_manager = Api::StemcellManager.new
    end

    def bind_deployment
      Models::Deployment.db.transaction do
        deployment = Models::Deployment.find(:name => @deployment_plan.name)
        # HACK, since canonical uniqueness is not enforced in the DB
        if deployment.nil?
          canonical_name_index = Set.new
          Models::Deployment.each do |other_deployment|
            canonical_name_index << canonical(other_deployment.name)
          end
          if canonical_name_index.include?(@deployment_plan.canonical_name)
            raise DeploymentCanonicalNameTaken,
                  "Invalid deployment name `#{@deployment_plan.name}', " +
                  "canonical name already taken"
          end
          deployment = Models::Deployment.create(:name => @deployment_plan.name)
        end
        @deployment_plan.deployment = deployment
      end
    end

    def bind_releases
      release_specs = @deployment_plan.releases

      release_specs.each do |release_spec|
        name = release_spec.name
        version = release_spec.version

        release = Models::Release[:name => name]
        if release.nil?
          raise DeploymentUnknownRelease, "Can't find release `#{name}'"
        end

        @logger.debug("Found release: #{release.pretty_inspect}")
        release_spec.release = release

        release_version = Models::ReleaseVersion[:release_id => release.id,
                                                 :version => version]

        if release_version.nil?
          raise DeploymentUnknownReleaseVersion,
                "Can't find release version `#{name}/#{version}'"
        end

        @logger.debug("Found release version: " +
                      "#{release_version.pretty_inspect}")
        release_spec.release_version = release_version

        deployment = @deployment_plan.deployment

        # TODO: this might not be needed anymore, as deployment is
        #       holding onto release version, release is reachable from there
        unless deployment.releases.include?(release)
          @logger.debug("Locking the release from deletion")
          deployment.add_release(release)
        end

        unless deployment.release_versions.include?(release_version)
          @logger.debug("Binding release version to deployment")
          deployment.add_release_version(release_version)
        end
      end
    end

    def bind_existing_deployment
      lock = Mutex.new
      ThreadPool.new(:max_threads => 32).wrap do |pool|
        @deployment_plan.deployment.vms.each do |vm|
          pool.process do
            with_thread_name("bind_existing_deployment(#{vm.agent_id})") do
              bind_existing_vm(lock, vm)
            end
          end
        end
      end
    end

    def bind_existing_vm(lock, vm)
      state = get_state(vm)
      lock.synchronize do
        @logger.debug("Processing network reservations")
        reservations = get_network_reservations(state)

        instance = vm.instance
        if instance
          bind_instance(instance, state, reservations)
        else
          @logger.debug("Binding resource pool VM")
          # TODO: protect against malformed state
          resource_pool = @deployment_plan.resource_pool(
              state["resource_pool"]["name"])
          if resource_pool
            bind_idle_vm(vm, resource_pool, state, reservations)
          else
            @logger.debug("Resource pool doesn't exist, marking for deletion")
            @deployment_plan.delete_vm(vm)
          end
        end
        @logger.debug("Finished binding VM")
      end
    end

    def bind_idle_vm(vm, resource_pool, state, reservations)
      @logger.debug("Adding to resource pool")
      idle_vm = resource_pool.add_idle_vm
      idle_vm.vm = vm
      idle_vm.current_state = state

      reservation = reservations[resource_pool.network.name]
      if reservation
        if reservation.static?
          @logger.debug("Releasing static network reservation for " +
                            "resource pool VM `#{vm.cid}'")
          resource_pool.network.release(reservation)
        else
          idle_vm.network_reservation = reservation
        end
      else
        @logger.debug("No network reservation for VM `#{vm.cid}'")
      end
    end

    def bind_instance(instance, state, reservations)
      @logger.debug("Binding instance VM")

      # Update instance, if we are renaming a job.
      if @deployment_plan.rename_in_progress? &&
         instance.job == @deployment_plan.job_rename["old_name"]
        new_name = @deployment_plan.job_rename["new_name"]
        @logger.info("Found instance with old job name #{instance.job}, " +
                     "updating it to `#{new_name}'")
        instance.job = new_name
        instance.save
      end

      # Does the job instance exist in the new deployment?
      if (job = @deployment_plan.job(instance.job)) &&
          (instance_spec = job.instance(instance.index))
        @logger.debug("Found job and instance spec")
        instance_spec.instance = instance
        instance_spec.current_state = state

        @logger.debug("Copying network reservations")
        instance_spec.take_network_reservations(reservations)

        @logger.debug("Copying resource pool reservation")
        job.resource_pool.mark_active_vm
      else
        @logger.debug("Job/instance not found, marking for deletion")
        @deployment_plan.delete_instance(instance)
      end
    end

    def get_network_reservations(state)
      reservations = {}
      state["networks"].each do |name, network_config|
        network = @deployment_plan.network(name)
        if network
          reservation = NetworkReservation.new(:ip => network_config["ip"])
          network.reserve(reservation)
          reservations[name] = reservation if reservation.reserved?
        end
      end
      reservations
    end

    def get_state(vm)
      @logger.debug("Requesting current VM state for: #{vm.agent_id}")
      agent = AgentClient.new(vm.agent_id)
      state = agent.get_state

      @logger.debug("Received VM state: #{state.pretty_inspect}")
      verify_state(vm, state)
      @logger.debug("Verified VM state")

      migrate_legacy_state(vm, state)
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

      actual_deployment_name = state["deployment"]
      expected_deployment_name = @deployment_plan.deployment.name

      if actual_deployment_name != expected_deployment_name
        raise AgentWrongDeployment,
              "VM `#{vm.cid}' is out of sync: " +
              "expected to be a part of deployment " +
              "`#{expected_deployment_name}' " +
              "but is actually a part of deployment " +
              "`#{actual_deployment_name}'"
      end

      actual_job = state["job"].is_a?(Hash) ? state["job"]["name"] : nil
      actual_index = state["index"]

      if instance.nil? && !actual_job.nil?
        raise AgentUnexpectedJob,
              "VM `#{vm.cid}' is out of sync: " +
              "it reports itself as `#{actual_job}/#{actual_index}' but " +
              "there is no instance reference in DB"
      end

      if instance &&
        (instance.job != actual_job || instance.index != actual_index)
        # Check if we are resuming a previously unfinished rename
        if actual_job == @deployment_plan.job_rename["old_name"] &&
           instance.job == @deployment_plan.job_rename["new_name"] &&
           instance.index == actual_index

          # Rename already happened in the DB but then something happened
          # and agent has never been updated.
          unless @deployment_plan.job_rename["force"]
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
        disk_size = state["persistent_disk"].to_i
        persistent_disk = instance.persistent_disk

        # This is to support legacy deployments where we did not have
        # the disk_size specified.
        if disk_size != 0 && persistent_disk && persistent_disk.size == 0
          persistent_disk.update(:size => disk_size)
        end
      end
    end

    def bind_resource_pools
      @deployment_plan.resource_pools.each do |resource_pool|
        resource_pool.missing_vm_count.times do
          resource_pool.add_idle_vm
        end

        resource_pool.idle_vms.each_with_index do |idle_vm, index|
          unless idle_vm.network_reservation
            network = resource_pool.network
            reservation = NetworkReservation.new(
                :type => NetworkReservation::DYNAMIC)
            network.reserve(reservation)

            unless reservation.reserved?
              handle_reservation_error(resource_pool.name, index, reservation)
            end

            idle_vm.network_reservation = reservation
          end
        end
      end
    end

    def bind_unallocated_vms
      @deployment_plan.jobs.each do |job|
        job.instances.each do |instance_spec|
          # create the instance model if this is a new instance
          instance = instance_spec.instance

          if instance.nil?
            # look up the instance again, in case it wasn't associated with a VM
            conditions = {
              :deployment_id => @deployment_plan.deployment.id,
              :job => job.name,
              :index => instance_spec.index
            }
            instance = Models::Instance.find_or_create(conditions) do |model|
              model.state = "started"
            end
            instance_spec.instance = instance
          end

          bind_instance_job_state(instance_spec)
          allocate_instance_vm(instance_spec) unless instance.vm
        end
      end
    end

    def allocate_instance_vm(instance_spec)
      resource_pool = instance_spec.job.resource_pool
      network = resource_pool.network
      idle_vm = resource_pool.allocate_vm
      if idle_vm.vm
        # try to reuse the existing reservation if possible
        instance_reservation = instance_spec.network_reservations[network.name]
        if instance_reservation
          instance_reservation.take(idle_vm.network_reservation)
        end
      else
        # if the VM is about to be created, then use this
        # instance networking configuration
        idle_vm.bound_instance = instance_spec

        # this also means we no longer need the VM network reservation
        network.release(idle_vm.network_reservation)
        idle_vm.network_reservation = nil
      end
      instance_spec.idle_vm = idle_vm
    end

    def bind_instance_job_state(instance_spec)
      instance = instance_spec.instance
      if instance_spec.state
        # Deployment plan already has state for this instance
        instance.update(:state => instance_spec.state)
      elsif instance.state
        # Instance has its state persisted from the previous deployment
        instance_spec.state = instance.state
      else
        # Target instance state should either be persisted in DB
        # or provided via deployment plan, otherwise something is really wrong
        raise InstanceTargetStateUndefined,
              "Instance `#{instance.job}/#{instance.index}' target state " +
              "cannot be determined"
      end
    end

    def bind_instance_networks
      @deployment_plan.jobs.each do |job|
        job.instances.each do |instance|
          instance.network_reservations.each do |name, reservation|
            unless reservation.reserved?
              network = @deployment_plan.network(name)
              network.reserve(reservation)
              unless reservation.reserved?
                handle_reservation_error(job.name, instance.index, reservation)
              end
            end
          end
        end
      end
    end

    def bind_templates
      @deployment_plan.releases.each do |release_spec|
        release_version = release_spec.release_version

        template_name_index = {}
        release_version.templates.each do |template|
          template_name_index[template.name] = template
        end

        package_name_index = {}
        release_version.packages.each do |package|
          package_name_index[package.name] = package
        end

        release_spec.templates.each do |template_spec|
          @logger.info("Binding template: #{template_spec.name}")
          template = template_name_index[template_spec.name]
          if template.nil?
            raise DeploymentUnknownTemplate,
                  "Can't find template `#{template_spec.name}'"
          end

          template_spec.template = template

          packages = []
          template.package_names.each do |package_name|
            packages << package_name_index[package_name]
          end
          template_spec.packages = packages

          @logger.debug("Bound template: #{template_spec.pretty_inspect}")
        end
      end
    end

    def bind_stemcells
      @deployment_plan.resource_pools.each do |resource_pool|
        stemcell_spec = resource_pool.stemcell
        name = stemcell_spec.name
        version = stemcell_spec.version

        lock = Lock.new("lock:stemcells:#{name}:#{version}", :timeout => 10)
        lock.lock do
          stemcell = @stemcell_manager.find_by_name_and_version(name, version)

          deployments = stemcell.deployments_dataset.
            filter(:deployment_id => @deployment_plan.deployment.id)

          if deployments.empty?
            stemcell.add_deployment(@deployment_plan.deployment)
          end
          stemcell_spec.stemcell = stemcell
        end
      end
    end

    def bind_configuration
      @deployment_plan.jobs.each { |job| ConfigurationHasher.new(job).hash }
    end

    def bind_dns
      domain = Models::Dns::Domain.find_or_create(:name => "bosh",
                                                  :type => "NATIVE")
      @deployment_plan.dns_domain = domain

      soa_record = Models::Dns::Record.find_or_create(:domain_id => domain.id,
                                                      :name => "bosh",
                                                      :type => "SOA")
      # TODO: make configurable?
      # The format of the SOA record is:
      # primary_ns contact serial refresh retry expire minimum
      soa_record.content = "localhost hostmaster@localhost 0 10800 604800 30"
      soa_record.ttl = 300
      soa_record.save
    end

    def bind_instance_vms
      unbound_instances = []

      @deployment_plan.jobs.each do |job|
        job.instances.each do |instance_spec|
          # Don't allocate resource pool VMs to instances in detached state
          next if instance_spec.state == "detached"
          # Skip bound instances
          next if instance_spec.instance.vm
          unbound_instances << instance_spec
        end
      end

      return if unbound_instances.empty?

      @event_log.begin_stage("Binding instance VMs", unbound_instances.size)

      ThreadPool.new(:max_threads => 32).wrap do |pool|
        unbound_instances.each do |instance_spec|
          pool.process do
            bind_instance_vm(instance_spec)
          end
        end
      end
    end

    def bind_instance_vm(instance_spec)
      instance = instance_spec.instance
      job = instance_spec.job
      idle_vm = instance_spec.idle_vm

      instance.update(:vm => idle_vm.vm)

      @event_log.track("#{job.name}/#{instance.index}") do
        # Apply the assignment to the VM
        state = idle_vm.current_state
        state["job"] = job.spec
        state["index"] = instance.index
        state["release"] = job.release.spec

        idle_vm.vm.update(:apply_spec => state)

        agent = AgentClient.new(idle_vm.vm.agent_id)
        agent.apply(state)
        instance_spec.current_state = state
      end
    end

    def delete_unneeded_vms
      unneeded_vms = @deployment_plan.unneeded_vms
      return if unneeded_vms.empty?

      @event_log.begin_stage("Deleting unneeded VMs", unneeded_vms.size)

      # TODO: make pool size configurable?
      ThreadPool.new(:max_threads => 10).wrap do |pool|
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
      return if unneeded_instances.empty?

      @event_log.begin_stage("Deleting unneeded instances",
                             unneeded_instances.size)
      InstanceDeleter.new(@deployment_plan).delete_instances(unneeded_instances)
      @logger.info("Deleted no longer needed instances")
    end

    ##
    # Handles the network reservation error and rethrows the proper exception
    # @param [String] name
    # @param [Integer] index
    # @param [NetworkReservation] reservation
    # @return [void]
    def handle_reservation_error(name, index, reservation)
      if reservation.static?
        formatted_ip = ip_to_netaddr(reservation.ip).ip
        case reservation.error
          when NetworkReservation::USED
            raise NetworkReservationAlreadyInUse,
                  "`#{name}/#{index}' asked for a static IP #{formatted_ip} " +
                  "but it's already reserved/in use"
          when NetworkReservation::WRONG_TYPE
            raise NetworkReservationWrongType,
                  "`#{name}/#{index}' asked for a static IP #{formatted_ip} " +
                  "but it's in the dynamic pool"
          else
            raise NetworkReservationError,
                  "`#{name}/#{index}' failed to reserve static IP " +
                  "#{formatted_ip}: #{reservation.error}"
        end
      else
        case reservation.error
          when NetworkReservation::CAPACITY
            raise NetworkReservationNotEnoughCapacity,
                  "`#{name}/#{index}' asked for a dynamic IP " +
                  "but there were no more available"
          else
            raise NetworkReservationError,
                  "`#{name}/#{index}' failed to reserve dynamic IP " +
                  "#{formatted_ip}: #{reservation.error}"
        end
      end
    end
  end
end
