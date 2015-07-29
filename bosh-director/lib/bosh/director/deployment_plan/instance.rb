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

      # @return [String] job state
      attr_reader :state

      # @return [DeploymentPlan::Vm] Associated resource pool VM
      attr_reader :vm

      attr_reader :deployment

      # Creates a new instance specification based on the job and index.
      # @param [DeploymentPlan::Job] job associated job
      # @param [Integer] index index for this instance
      def initialize(job, index, state, deployment, logger)
        @job = job
        @index = index
        @logger = logger
        @deployment = deployment
        @name = "#{@job.name}/#{@index}"

        @configuration_hash = nil
        @template_hashes = nil
        @vm = nil
        @current_state = {}

        @network_reservations = {}
        @state = state

        # Expanding virtual states
        case @state
          when 'recreate'
            @state = 'started'
          when 'restart'
            @restart = true
            @state = 'started'
        end
      end

      def job_name
        @job.name
      end

      def to_s
        @name
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

      def reserve_networks
        @network_reservations.each do |network, reservation|
          unless reservation.reserved?
            network.reserve!(reservation, "`#{@name}'")
          end
        end
      end

      def resource_pool
        @job.resource_pool
      end

      def deployment_model
        @deployment.model
      end

      ##
      # Updates this domain object to reflect an existing instance running on an existing vm
      def bind_existing_instance(instance_model, state)
        check_model_not_bound
        @model = instance_model
        allocate_vm
        @vm.model = instance_model.vm

        reservations = StateNetworkReservations.new(@deployment).create_from_state(self, state)
        take_network_reservations(reservations)

        @current_state = state
        @logger.debug("Found VM '#{@vm.model.cid}' running job instance '#{self}'")
      end

      def apply_vm_state
        @logger.info('Applying VM state')

        state = spec
        @model.vm.update(:apply_spec => state)
        agent_client.apply(state)

        # Agent will potentially return modified version of state
        # with resolved dynamic networks information
        @current_state = agent_client.get_state
      end

      def update_trusted_certs
        agent_client.update_settings(Config.trusted_certs)
        @model.vm.update(:trusted_certs_sha1 => Digest::SHA1.hexdigest(Config.trusted_certs))
      end

      def agent_client
        @agent_client ||= AgentClient.with_vm(@model.vm)
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
      # @param [DeploymentPlan::Network] network
      # @param [NetworkReservation] reservation
      def add_network_reservation(network, reservation)
        old_reservation = @network_reservations[network]

        if old_reservation
          raise NetworkReservationAlreadyExists,
                "`#{self}' already has reservation " +
                "for network `#{network.name}', IP #{old_reservation.ip}"
        end
        @network_reservations[network] = reservation
      end

      def with_network_update
        ips_before_update = network_to_ip(@current_state['networks'])
        yield
        ips_after_update = network_to_ip(network_settings)
        ips_to_release = ips_before_update.to_set - ips_after_update.to_set
        release_ips(ips_to_release)
      end

      ##
      # @return [Hash] BOSH network settings used for Agent apply call
      def network_settings
        default_properties = {}
        @job.default_network.each do |key, value|
          (default_properties[value] ||= []) << key
        end

        network_settings = {}
        @network_reservations.each do |network, reservation|
          network_settings[network.name] = network.network_settings(reservation, default_properties[network.name])

          # Temporary hack for running errands.
          # We need to avoid RunErrand task thinking that
          # network configuration for errand VM differs
          # from network configuration for its Instance.
          #
          # Obviously this does not account for other changes
          # in network configuration that errand job might need.
          # (e.g. errand job desires static ip)
          if @job.starts_on_deploy?
            network_settings[network.name]['dns_record_name'] = dns_record_name(network.name)
          end

          # Somewhat of a hack: for dynamic networks we might know IP address, Netmask & Gateway
          # if they're featured in agent state, in that case we put them into network spec to satisfy
          # ConfigurationHasher in both agent and director.
          if @current_state.is_a?(Hash) &&
              @current_state['networks'].is_a?(Hash) &&
              @current_state['networks'][network.name].is_a?(Hash) &&
              network_settings[network.name]['type'] == 'dynamic'
            %w(ip netmask gateway).each do |key|
              network_settings[network.name][key] = @current_state['networks'][network.name][key]
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
        @current_state['persistent_disk'].to_i > 0
      end

      ##
      # @return [Boolean] returns true if the network configuration changed
      def networks_changed?
        network_settings != @current_state['networks']
      end

      ##
      # @return [Boolean] returns true if the expected resource pool differs from the one provided by the VM
      def resource_pool_changed?
        if @job.deployment.recreate
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

      def delete
        @network_reservations.each do |network, reservation|
          network.release(reservation) if reservation.reserved?
          @network_reservations.delete(network)
        end

        @model.destroy
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
          'deployment' => @deployment.name,
          'job' => job.spec,
          'index' => index,
          'networks' => network_settings,
          'resource_pool' => job.resource_pool.spec,
          'packages' => job.package_spec,
          'configuration_hash' => configuration_hash,
          'properties' => job.properties,
          'dns_domain_name' => dns_domain_name,
          'links' => job.link_spec,
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

        if rendered_templates_archive
          spec['rendered_templates_archive'] = rendered_templates_archive.spec
        end

        spec
      end

      def vm_created?
        !@vm.model.nil? && @vm.model.vm_exists?
      end

      def bind_to_vm_model(vm_model)
        @model.update(vm: vm_model)
        @vm.model = vm_model
        @vm.bound_instance = self
      end

      # Allocates an VM in this job resource pool and binds current instance to that VM.
      # @return [void]
      def allocate_vm
        vm = Vm.new

        # VM is not created yet: let's just make it reference this instance
        # so later it knows what it needs to become
        vm.bound_instance = self
        @vm = vm
      end

      private

      # Looks up instance model in DB
      # @return [Models::Instance]
      def find_or_create_model
        if @deployment.model.nil?
          raise DirectorError, 'Deployment model is not bound'
        end

        conditions = {
          deployment_id: @deployment.model.id,
          job: @job.name,
          index: @index
        }

        Models::Instance.find_or_create(conditions) do |model|
          model.state = 'started'
        end
      end

      # @param <[String, String]> ips_set set of [network_name, ip]
      def release_ips(ips_set)
        ips_set.each do |network_name, ip|
          Bosh::Director::Models::IpAddress.where(
            address: NetAddr::CIDR.create(ip).to_i,
            network_name: network_name
          ).delete
        end
      end

      # @param [Hash] network_settings map of network name to settings
      # @return [Hash] map of network name to IP address
      def network_to_ip(network_settings)
        Hash[network_settings.map { |network_name, settings| [network_name, settings['ip']] }]
      end

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
        reservations.each do |network, provided_reservation|
          reservation = @network_reservations[network]
          if reservation
            @logger.debug("Copying job instance `#{self}' network reservation #{provided_reservation}")
            reservation.take(provided_reservation)
          end
        end
      end
    end
  end
end
