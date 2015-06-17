module Bosh::Director
  module DeploymentPlan
    # Represents a single job instance.
    class Instance
      include DnsHelper

      # @return [DeploymentPlan::Job] Associated job
      attr_reader :job

      # @return [Integer] Instance index
      attr_reader :index

      # @return [Models::Instance] Instance model
      attr_reader :model

      # @return [String] Checksum all of the configuration templates
      attr_accessor :configuration_hash

      # @return [Hash] A hash of template SHA1 hashes
      attr_accessor :template_hashes

      # @return [Bosh::Director::Core::Templates::RenderedTemplatesArchive]
      attr_accessor :rendered_templates_archive

      # @return [Hash<String, NetworkReservation>] network reservations
      attr_accessor :network_reservations

      # @return [String] job state
      attr_accessor :state

      # @return [Hash] current state as provided by the BOSH Agent
      attr_reader :current_state

      # @return [DeploymentPlan::Vm] Associated resource pool VM
      attr_reader :vm

      # @return [Boolean] true if this instance needs to be recreated
      attr_accessor :recreate

      # @return [Boolean] true if this instance needs to be restarted
      attr_accessor :restart

      # Creates a new instance specification based on the job and index.
      # @param [DeploymentPlan::Job] job associated job
      # @param [Integer] index index for this instance
      def initialize(job, index, logger)
        @job = job
        @index = index
        @logger = logger

        @configuration_hash = nil
        @template_hashes = nil
        @vm = nil
        @current_state = nil

        @network_reservations = {}
        @state = job.instance_state(@index)

        # Expanding virtual states
        case @state
          when 'recreate'
            @recreate = true
            @state = 'started'
          when 'restart'
            @restart = true
            @state = 'started'
        end
      end

      def to_s
        "#{@job.name}/#{@index}"
      end

      # Looks up instance model in DB and binds it to this instance spec.
      # Instance model is created if it's not found in DB. New VM is
      # allocated if instance DB record doesn't reference one.
      # @return [void]
      def bind_unallocated_vm
        @model ||= find_or_create_model
        if @model.vm.nil?
          allocate_vm
        end
      end

      ##
      # Updates this domain object to reflect an existing instance running on an existing vm
      def bind_existing_instance(instance_model, state, reservations)
        check_model_not_bound

        @model = instance_model
        @current_state = state

        take_network_reservations(reservations)
        add_allocated_vm(instance_model.vm, state)
      end

      def apply_partial_vm_state
        @logger.info('Applying partial VM state')

        state = @vm.current_state
        state['job'] = job.spec
        state['index'] = index

        # Apply the assignment to the VM
        agent = AgentClient.with_defaults(@vm.model.agent_id)
        agent.apply(state)

        # Our assumption here is that director database access
        # is much less likely to fail than VM agent communication
        # so we only update database after we see a successful agent apply.
        # If database update fails subsequent deploy will try to
        # assign a new VM to this instance which is ok.
        @vm.model.db.transaction do
          @vm.model.update(:apply_spec => state)
          @model.update(:vm => @vm.model)
        end

        @current_state = state
      end

      def apply_vm_state
        @logger.info('Applying VM state')

        state = {
          'deployment' => @job.deployment.name,
          'networks' => network_settings,
          'resource_pool' => @job.resource_pool.spec,
          'job' => @job.spec,
          'index' => @index,
        }

        if disk_size > 0
          state['persistent_disk'] = disk_size
        end

        @model.vm.update(:apply_spec => state)

        agent = AgentClient.with_defaults(@model.vm.agent_id)
        agent.apply(state)

        # Agent will potentially return modified version of state
        # with resolved dynamic networks information
        @current_state = agent.get_state
      end

      ##
      # Syncs instance state with instance model in DB. This is needed because
      # not all instance states are available in the deployment manifest and we
      # we cannot really persist this data in the agent state (as VM might be
      # stopped or detached).
      # @return [void]
      def sync_state_with_db
        check_model_bound

        if @state
          # Deployment plan explicitly sets state for this instance
          @model.update(:state => @state)
        elsif @model.state
          # Instance has its state persisted from the previous deployment
          @state = @model.state
        else
          # Target instance state should either be persisted in DB or provided
          # via deployment plan, otherwise something is really wrong
          raise InstanceTargetStateUndefined,
                "Instance `#{self}' target state cannot be determined"
        end
      end

      ##
      # Adds a new network to this instance
      # @param [String] name network name
      # @param [NetworkReservation] reservation
      def add_network_reservation(name, reservation)
        old_reservation = @network_reservations[name]

        if old_reservation
          raise NetworkReservationAlreadyExists,
                "`#{self}' already has reservation " +
                "for network `#{name}', IP #{old_reservation.ip}"
        end
        @network_reservations[name] = reservation
      end

      ##
      # @return [Hash] BOSH network settings used for Agent apply call
      def network_settings
        default_properties = {}
        @job.default_network.each do |key, value|
          (default_properties[value] ||= []) << key
        end

        network_settings = {}
        @network_reservations.each do |name, reservation|
          network = @job.deployment.network(name)
          network_settings[name] = network.network_settings(reservation, default_properties[name])

          # Temporary hack for running errands.
          # We need to avoid RunErrand task thinking that
          # network configuration for errand VM differs
          # from network configuration for its Instance.
          #
          # Obviously this does not account for other changes
          # in network configuration that errand job might need.
          # (e.g. errand job desires static ip)
          if @job.starts_on_deploy?
            network_settings[name]['dns_record_name'] = dns_record_name(name)
          end

          # Somewhat of a hack: for dynamic networks we might know IP address, Netmask & Gateway
          # if they're featured in agent state, in that case we put them into network spec to satisfy
          # ConfigurationHasher in both agent and director.
          if @current_state.is_a?(Hash) &&
              @current_state['networks'].is_a?(Hash) &&
              @current_state['networks'][name].is_a?(Hash) &&
              network_settings[name]['type'] == 'dynamic'
            %w(ip netmask gateway).each do |key|
              network_settings[name][key] = @current_state['networks'][name][key]
            end
          end
        end
        network_settings
      end

      ##
      # @return [Integer] persistent disk size
      def disk_size
        check_model_bound

        if @model.persistent_disk
          @model.persistent_disk.size
        else
          0
        end
      end

      ##
      # @return [Hash] persistent disk cloud properties
      def disk_cloud_properties
        check_model_bound

        if @model.persistent_disk
          @model.persistent_disk.cloud_properties
        else
          {}
        end
      end

      ##
      # @return [Hash<String, String>] dns record hash of dns name and IP
      def dns_record_info
        dns_record_info = {}
        network_settings.each do |network_name, network|
          name = dns_record_name(network_name)
          dns_record_info[name] = network['ip']
        end
        dns_record_info
      end

      ##
      # @return [String] dns record name
      def dns_record_name(network_name)
        [index, job.canonical_name, canonical(network_name), job.deployment.canonical_name, dns_domain_name].join('.')
      end

      ##
      # @return [Boolean] returns true if the persistent disk is attached to the VM
      def disk_currently_attached?
        current_state['persistent_disk'].to_i > 0
      end

      ##
      # @return [Boolean] returns true if the network configuration changed
      def networks_changed?
        network_settings != @current_state['networks']
      end

      ##
      # @return [Boolean] returns true if the expected resource pool differs from the one provided by the VM
      def resource_pool_changed?
        if @recreate || @job.deployment.recreate
          return true
        end

        if @job.resource_pool.spec != @current_state['resource_pool']
          return true
        end

        # env is not a part of a resource pool spec but rather gets persisted
        # in director DB, hence the check below
        # NOTE: we only update VMs that have env persisted to avoid recreating
        # everything, so if the director gets updated from the version that
        # doesn't persist VM env to the version that does, there needs to
        # be at least one deployment that recreates all VMs before the following
        # code path gets exercised.
        if @model && @model.vm && @model.vm.env && @job.resource_pool.env != @model.vm.env
          return true
        end

        false
      end

      ##
      # @return [Boolean] returns true if the expected configuration hash
      #   differs from the one provided by the VM
      def configuration_changed?
        configuration_hash != @current_state['configuration_hash']
      end

      ##
      # @return [Boolean] returns true if the expected job configuration differs
      #   from the one provided by the VM
      def job_changed?
        return true if @current_state.nil?

        job_spec = @job.spec
        if job_spec != @current_state['job']
          # The agent job spec could be in legacy form.  job_spec cannot be,
          # though, because we got it from the spec function in job.rb which
          # automatically makes it non-legacy.
          return job_spec != Job.convert_from_legacy_spec(@current_state['job'])
        end
        return false
      end

      ##
      # @return [Boolean] returns true if the expected packaged of the running
      #   instance differ from the ones provided by the VM
      def packages_changed?
        @job.package_spec != @current_state['packages']
      end

      ##
      # @return [Boolean] returns true if the expected persistent disk or cloud_properties differs
      #   from the state currently configured on the VM
      def persistent_disk_changed?
        new_disk_size = @job.persistent_disk_pool ? @job.persistent_disk_pool.disk_size : 0
        new_disk_cloud_properties = @job.persistent_disk_pool ? @job.persistent_disk_pool.cloud_properties : {}
        return true if new_disk_size != disk_size

        new_disk_size != 0 && new_disk_cloud_properties != disk_cloud_properties
      end

      ##
      # @return [Boolean] returns true if the DNS records configured for the
      #   instance differ from the ones configured on the DNS server
      def dns_changed?
        if Config.dns_enabled?
          dns_record_info.any? do |name, ip|
            Models::Dns::Record.find(:name => name, :type => 'A',
                                     :content => ip).nil?
          end
        else
          false
        end
      end

      ##
      # Checks if agent view of the instance state is consistent with target
      # instance state.
      #
      # In case the instance current state is 'detached' we should never get to
      # this method call.
      # @return [Boolean] returns true if the expected job state differs from
      #   the one provided by the VM
      def state_changed?
        @state == 'detached' ||
          @state == 'started' && @current_state['job_state'] != 'running' ||
          @state == 'stopped' && @current_state['job_state'] == 'running'
      end

      ##
      # Checks if the target VM already has the same set of trusted SSL certificates
      # as the director currently wants to install on all managed VMs. This will
      # differ for VMs that existed before the director's configuration changed.
      #
      # @return [Boolean] true if the VM needs to be sent a new set of trusted certificates
      def trusted_certs_changed?
        Digest::SHA1.hexdigest(Bosh::Director::Config.trusted_certs) != @model.vm.trusted_certs_sha1
      end

      ##
      # @return [Boolean] returns true if the any of the expected specifications
      #   differ from the ones provided by the VM
      def changed?
        !changes.empty?
      end

      ##
      # @return [Set<Symbol>] returns a set of all of the specification differences
      def changes
        changes = Set.new
        unless @state == 'detached' && @current_state.nil?
          changes << :restart if @restart
          changes << :resource_pool if resource_pool_changed?
          changes << :network if networks_changed?
          changes << :packages if packages_changed?
          changes << :persistent_disk if persistent_disk_changed?
          changes << :configuration if configuration_changed?
          changes << :job if job_changed?
          changes << :state if state_changed?
          changes << :dns if dns_changed?
          changes << :trusted_certs if trusted_certs_changed?
        end
        changes
      end

      ##
      # Instance spec that's passed to the VM during the BOSH Agent apply call.
      # It's what's used for comparing the expected vs the actual state.
      # @return [Hash<String, Object>] instance spec
      def spec
        spec = {
          'deployment' => @job.deployment.name,
          'job' => job.spec,
          'index' => index,
          'networks' => network_settings,
          'resource_pool' => job.resource_pool.spec,
          'packages' => job.package_spec,
          'configuration_hash' => configuration_hash,
          'properties' => job.properties,
          'dns_domain_name' => dns_domain_name
        }

        if job.persistent_disk_pool
          # supply both for reverse compatibility with old agent
          spec['persistent_disk'] = job.persistent_disk_pool.disk_size
          # old agents will ignore this pool
          spec['persistent_disk_pool'] = job.persistent_disk_pool.spec
        else
          spec['persistent_disk'] = 0
        end

        if template_hashes
          spec['template_hashes'] = template_hashes
        end

        # Ruby BOSH Agent does not look at 'rendered_templates_archive'
        # since it renders job templates and then compares template hashes.
        # Go BOSH Agent has no ability to render ERB so pre-rendered templates are provided.
        if rendered_templates_archive
          spec['rendered_templates_archive'] = rendered_templates_archive.spec
        end

        spec
      end

      def bind_to_vm_model(vm_model)
        @model.update(vm: vm_model)
        @vm.model = vm_model
        @vm.bound_instance = self
      end

      # Looks up instance model in DB
      # @return [Models::Instance]
      def find_or_create_model
        if @job.deployment.model.nil?
          raise DirectorError, 'Deployment model is not bound'
        end

        conditions = {
          deployment_id: @job.deployment.model.id,
          job: @job.name,
          index: @index
        }

        Models::Instance.find_or_create(conditions) do |model|
          model.state = 'started'
        end
      end

      # Allocates an VM in this job resource pool and binds current instance to that VM.
      # @return [void]
      def allocate_vm
        resource_pool = @job.resource_pool
        vm = resource_pool.allocate_vm
        network = resource_pool.network

        if vm.model
          # There's already a resource pool VM that can become our instance,
          # so we can try to reuse its reservation
          instance_reservation = @network_reservations[network.name]
          if instance_reservation
            instance_reservation.take(vm.network_reservation)
          end
        else
          # VM is not created yet: let's just make it reference this instance
          # so later it knows what it needs to become
          vm.bound_instance = self

          # this also means we no longer need previous VM network reservation
          # (instance has its own)
          vm.release_reservation
        end

        @vm = vm
      end

      private

      def check_model_bound
        if @model.nil?
          raise DirectorError, "Instance `#{self}' model is not bound"
        end
      end

      def check_model_not_bound
        raise DirectorError, "Instance `#{self}' model is already bound" if @model
      end

      ##
      # Take any existing valid network reservations
      # @param [Hash<String, NetworkReservation>] reservations
      # @return [void]
      def take_network_reservations(reservations)
        reservations.each do |name, provided_reservation|
          reservation = @network_reservations[name]
          if reservation
            @logger.debug("Copying job instance `#{self}' network reservation #{provided_reservation}")
            reservation.take(provided_reservation)
          end
        end
      end

      def add_allocated_vm(vm_model, state)
        resource_pool = @job.resource_pool
        vm = resource_pool.add_allocated_vm

        reservation = @network_reservations[vm.resource_pool.network.name]

        @logger.debug("Found VM '#{vm_model.cid}' running job instance '#{self}'" +
          " in resource pool `#{resource_pool.name}'" +
          " with reservation '#{reservation}'")
        vm.model = vm_model
        vm.bound_instance = self
        vm.current_state = state
        vm.use_reservation(reservation)

        @vm = vm
      end
    end
  end
end
