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
      attr_accessor :current_state

      # @return [DeploymentPlan::IdleVm] Associated resource pool VM
      attr_reader :idle_vm

      # @return [Boolean] true if this instance needs to be recreated
      attr_accessor :recreate

      # @return [Boolean] true if this instance needs to be restarted
      attr_accessor :restart

      ##
      # Creates a new instance specification based on the job and index.
      #
      # @param [DeploymentPlan::Job] job associated job
      # @param [Integer] index index for this instance
      def initialize(job, index)
        @job = job
        @index = index
        @model = nil
        @configuration_hash = nil
        @template_hashes = nil
        @idle_vm = nil
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

      # @param [Models::Instance] model Instance DB model
      # @return [void]
      def use_model(model)
        if @model
          raise DirectorError, 'Instance model is already bound'
        end
        @model = model
      end

      # Looks up a DB model for this instance, creates one if doesn't exist
      # yet.
      # @return [void]
      def bind_model
        @model ||= find_or_create_model
      end

      # Looks up instance model in DB and binds it to this instance spec.
      # Instance model is created if it's not found in DB. New idle VM is
      # allocated if instance DB record doesn't reference one.
      # @return [void]
      def bind_unallocated_vm
        bind_model
        if @model.vm.nil?
          allocate_idle_vm
        end
      end

      # Syncs instance state with instance model in DB. This is needed because
      # not all instance states are available in the deployment manifest and we
      # we cannot really persist this data in the agent state (as VM might be
      # stopped or detached).
      # @return [void]
      def sync_state_with_db
        if @model.nil?
          raise DirectorError, "Instance `#{self}' model is not bound"
        end

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
      # Take any existing valid network reservations
      #
      # @param [Hash<String, NetworkReservation] reservations
      # @return [void]
      def take_network_reservations(reservations)
        reservations.each do |name, provided_reservation|
          reservation = @network_reservations[name]
          reservation.take(provided_reservation) if reservation
        end
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
          network_settings[name]['dns_record_name'] = dns_record_name(name)

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
        if @model.nil?
          current_state['persistent_disk'].to_i
        elsif @model.persistent_disk
          @model.persistent_disk.size
        else
          0
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
      # @return [Boolean] returns true if the persistent disk is attached to the
      #   VM
      def disk_currently_attached?
        current_state['persistent_disk'].to_i > 0
      end

      ##
      # @return [Boolean] returns true if the network configuration changed
      def networks_changed?
        network_settings != @current_state['networks']
      end

      ##
      # @return [Boolean] returns true if the expected resource pool differs
      #   from the one provided by the VM
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
        if @model && @model.vm && @model.vm.env &&
          @job.resource_pool.env != @model.vm.env
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
      # @return [Boolean] returns true if the expected persistent disk differs
      #   from the one currently configured on the VM
      def persistent_disk_changed?
        @job.persistent_disk != disk_size
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
      # @return [Boolean] returns true if the any of the expected specifications
      #   differ from the ones provided by the VM
      def changed?
        !changes.empty?
      end

      ##
      # @return [Set<Symbol>] returns a set of all of the specification
      #   differences
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
        end
        changes
      end

      ##
      # Instance spec that's passed to the VM during the BOSH Agent apply call.
      # It's what's used for comparing the expected vs the actual state.
      #
      # @return [Hash<String, Object>] instance spec
      def spec
        spec = {
          'deployment' => @job.deployment.name,
          'job' => job.spec,
          'index' => index,
          'networks' => network_settings,
          'resource_pool' => job.resource_pool.spec,
          'packages' => job.package_spec,
          'persistent_disk' => job.persistent_disk,
          'configuration_hash' => configuration_hash,
          'properties' => job.properties,
          'dns_domain_name' => dns_domain_name
        }

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

      # Allocates an idle VM in this job resource pool and binds current
      # instance to that idle VM.
      # @return [void]
      def allocate_idle_vm
        resource_pool = @job.resource_pool
        idle_vm = resource_pool.allocate_vm
        network = resource_pool.network

        if idle_vm.vm
          # There's already a resource pool VM that can become our instance,
          # so we can try to reuse its reservation
          instance_reservation = @network_reservations[network.name]
          if instance_reservation
            instance_reservation.take(idle_vm.network_reservation)
          end
        else
          # VM is not created yet: let's just make it reference this instance
          # so later it knows what it needs to become
          idle_vm.bound_instance = self
          # this also means we no longer need previous VM network reservation
          # (instance has its own)
          idle_vm.release_reservation
        end

        @idle_vm = idle_vm
      end
    end
  end
end
