require 'securerandom'

module Bosh::Director
  module DeploymentPlan
    # Represents a single job instance.
    class Instance
      include DnsHelper

      # @return [DeploymentPlan::Job] Associated job
      attr_reader :job

      # @return [Integer] Instance index
      attr_reader :index

      attr_reader :uuid

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

      attr_reader :current_state

      attr_reader :availability_zone

      # @return [DeploymentPlan::Vm] Associated resource pool VM
      attr_reader :vm

      attr_reader :deployment

      attr_reader :existing_network_reservations

      def self.fetch_existing(desired_instance, existing_instance_model, existing_instance_state, logger)
        logger.debug("Fetching existing instance for: #{existing_instance_model.inspect}")
        # if state was not specified in manifest, use saved state
        job_state = desired_instance.state || existing_instance_model.state
        instance = new(desired_instance.job, desired_instance.index, job_state, desired_instance.deployment, existing_instance_state, desired_instance.az, desired_instance.bootstrap?, logger)
        instance.bind_existing_instance_model(existing_instance_model)
        instance.bind_existing_reservations(existing_instance_state)
        instance
      end

      def self.create(desired_instance, index, logger)
        job_state = desired_instance.state || 'started'
        instance = new(desired_instance.job, index, job_state, desired_instance.deployment, nil, desired_instance.az, desired_instance.bootstrap?, logger)
        instance.bind_new_instance_model
        instance
      end

      def self.fetch_obsolete(existing_instance, logger)
        InstanceFromDatabase.create_from_model(existing_instance, logger)
      end

      # Creates a new instance specification based on the job and index.
      # @param [DeploymentPlan::Job] job associated job
      # @param [Integer] index index for this instance
      def initialize(job, index, state, deployment, instance_state, availability_zone, bootstrap, logger)
        @job = job
        @index = index
        @availability_zone = availability_zone
        @logger = logger
        @deployment = deployment
        @bootstrap = bootstrap
        @name = "#{@job.name}/#{@index}"

        @configuration_hash = nil
        @template_hashes = nil
        @vm = nil
        @current_state = instance_state || {}

        # reservation generated from current state/DB
        @existing_network_reservations = InstanceNetworkReservations.new(logger)

        @state = state
      end

      def bootstrap?
        @bootstrap
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
      # TODO: This should just be responsible to allocating the VMs and not creating instance_models
      def bind_unallocated_vm
        ensure_model_bound
        ensure_vm_allocated
      end

      def ensure_model_bound
        @model ||= find_or_create_model
      end

      def bind_new_instance_model
        @model = Models::Instance.create({
            deployment_id: deployment.model.id,
            job: job.name,
            index: index,
            state: 'started',
            compilation: job.compilation?,
            uuid: SecureRandom.uuid,
            availability_zone: availability_zone_name,
            bootstrap: bootstrap?
          })
        @uuid = @model.uuid
      end

      def ensure_vm_allocated
        @uuid = @model.uuid
        if @model.vm.nil?
          allocate_vm
        end
      end

      def resource_pool
        @job.resource_pool
      end

      def deployment_model
        @deployment.model
      end

      # Updates this domain object to reflect an existing instance running on an existing vm
      def bind_existing_instance_model(existing_instance_model)
        @uuid = existing_instance_model.uuid
        check_model_not_bound
        @model = existing_instance_model
        allocate_vm
        @vm.model = existing_instance_model.vm
      end

      def bind_existing_reservations(state)
        @existing_network_reservations = InstanceNetworkReservations.create_from_db(self, @deployment, @logger)
        if @existing_network_reservations.none? && state
          # This is for backwards compatibility when we did not store
          # network reservations in DB and constructed them from instance state
          @existing_network_reservations = InstanceNetworkReservations.create_from_state(self, state, @deployment, @logger)
        end
      end

      def apply_vm_state
        @logger.info('Applying VM state')

        state = apply_spec
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

      def update_cloud_properties!
        @model.update(cloud_properties: JSON.dump(cloud_properties))
      end

      def agent_client
        @agent_client ||= AgentClient.with_vm(@model.vm)
      end

      def network_settings
        instance_plan = job.sorted_instance_plans.find {|instance_plan| instance_plan.instance.uuid == uuid }
        desired_reservations = instance_plan.network_plans.reject(&:obsolete?).map {|network_plan| network_plan.reservation }
        NetworkSettings.new(job.name, job.can_run_as_errand?, job.deployment.name, job.default_network, desired_reservations, @current_state, availability_zone, @index, @uuid)
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
      # @return [String] dns record name
      def dns_record_name(hostname, network_name)
        [hostname, job.canonical_name, canonical(network_name), job.deployment.canonical_name, dns_domain_name].join('.')
      end

      ##
      # @return [Boolean] returns true if the persistent disk is attached to the VM
      def disk_currently_attached?
        @current_state['persistent_disk'].to_i > 0
      end

      def cloud_properties_changed?
        changed = cloud_properties != @model.cloud_properties_hash
        log_changes(__method__, @model.cloud_properties_hash, cloud_properties) if changed
        changed
      end

      ##
      # @return [Boolean] returns true if the expected resource pool differs from the one provided by the VM
      def resource_pool_changed?
        if @job.deployment.recreate
          @logger.debug("#{__method__} job deployment is configured with \"recreate\" state")
          return true
        end

        if @job.resource_pool.spec != @current_state['resource_pool']
          log_changes(__method__, @current_state['resource_pool'], @job.resource_pool.spec)
          return true
        end

        # env is not a part of a resource pool spec but rather gets persisted
        # in director DB, hence the check below
        # NOTE: we only update VMs that have env persisted to avoid recreating
        # everything, so if the director gets updated from the version that
        # doesn't persist VM env to the version that does, there needs to
        # be at least one deployment that recreates all VMs before the following
        # code path gets exercised.
        changed = @model && @model.vm && @model.vm.env && @job.resource_pool.env != @model.vm.env
        if changed
          log_changes(__method__, @model.vm.env, @job.resource_pool.env)
          return true
        end
        false
      end

      ##
      # @return [Boolean] returns true if the expected configuration hash
      #   differs from the one provided by the VM
      def configuration_changed?
        changed = configuration_hash != @current_state['configuration_hash']
        log_changes(__method__, @current_state['configuration_hash'], configuration_hash) if changed
        changed
      end

      ##
      # @return [Boolean] returns true if the expected job configuration differs
      #   from the one provided by the VM
      def job_changed?
        return true if @current_state.nil?

        job_spec = @job.spec
        # The agent job spec could be in legacy form.  job_spec cannot be,
        # though, because we got it from the spec function in job.rb which
        # automatically makes it non-legacy.
        converted_current = Job.convert_from_legacy_spec(@current_state['job'])
        changed = job_spec != converted_current
        log_changes(__method__, converted_current, job_spec) if changed
        changed
      end

      ##
      # @return [Boolean] returns true if the expected packaged of the running
      #   instance differ from the ones provided by the VM
      def packages_changed?
        changed = @job.package_spec != @current_state['packages']
        log_changes(__method__, @current_state['packages'], @job.package_spec) if changed
        changed
      end

      ##
      # @return [Boolean] returns true if the expected persistent disk or cloud_properties differs
      #   from the state currently configured on the VM
      def persistent_disk_changed?
        new_disk_size = @job.persistent_disk_type ? @job.persistent_disk_type.disk_size : 0
        new_disk_cloud_properties = @job.persistent_disk_type ? @job.persistent_disk_type.cloud_properties : {}
        changed = new_disk_size != disk_size
        log_changes(__method__, "disk size: #{disk_size}", "disk size: #{new_disk_size}") if changed
        return true if changed

        changed = new_disk_size != 0 && new_disk_cloud_properties != disk_cloud_properties
        log_changes(__method__, disk_cloud_properties, new_disk_cloud_properties) if changed
        changed
      end

      ##
      # @return [Boolean] returns true if the DNS records configured for the
      #   instance differ from the ones configured on the DNS server
      def dns_changed?
        if Config.dns_enabled?
          network_settings.dns_record_info.any? do |name, ip|
            not_found = Models::Dns::Record.find(:name => name, :type => 'A', :content => ip).nil?
            @logger.debug("#{__method__} The requested dns record with name '#{name}' and ip '#{ip}' was not found in the db.") if not_found
            not_found
          end
        else
          false
        end
      end

      def current_job_state
        @current_state['job_state']
      end

      def update_state
        @model.update(state: @state)
      end

      ##
      # Checks if the target VM already has the same set of trusted SSL certificates
      # as the director currently wants to install on all managed VMs. This will
      # differ for VMs that existed before the director's configuration changed.
      #
      # @return [Boolean] true if the VM needs to be sent a new set of trusted certificates
      def trusted_certs_changed?
        model_trusted_certs = @model.vm.trusted_certs_sha1
        config_trusted_certs = Digest::SHA1.hexdigest(Bosh::Director::Config.trusted_certs)
        changed = config_trusted_certs != model_trusted_certs
        log_changes(__method__, model_trusted_certs, config_trusted_certs) if changed
        changed
      end

      ##
      # Instance spec that's passed to the VM during the BOSH Agent apply call.
      # It's what's used for comparing the expected vs the actual state.
      # @return [Hash<String, Object>] instance spec
      def apply_spec
        spec = {
          'deployment' => @deployment.name,
          'job' => job.spec,
          'index' => index,
          'id' => uuid,
          'networks' => network_settings.to_hash,
          'resource_pool' => job.resource_pool.spec,
          'packages' => job.package_spec,
          'configuration_hash' => configuration_hash,
          'dns_domain_name' => dns_domain_name,
        }

        if job.persistent_disk_type
          spec['persistent_disk'] = job.persistent_disk_type.disk_size
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

      def template_spec
        spec = {
          'deployment' => @deployment.name,
          'job' => job.spec,
          'index' => index,
          'bootstrap' => @bootstrap,
          'id' => uuid,
          'availability_zone' => availability_zone_name,
          'networks' => network_settings.to_hash,
          'resource_pool' => job.resource_pool.spec,
          'packages' => job.package_spec,
          'properties' => job.properties,
          'dns_domain_name' => dns_domain_name,
          'links' => job.link_spec,
        }

        if job.persistent_disk_type
          # supply both for reverse compatibility with old agent
          spec['persistent_disk'] = job.persistent_disk_type.disk_size
          # old agents will ignore this pool
          # keep disk pool for backwards compatibility
          spec['persistent_disk_pool'] = job.persistent_disk_type.spec
          spec['persistent_disk_type'] = job.persistent_disk_type.spec
        else
          spec['persistent_disk'] = 0
        end

        if template_hashes
          spec['template_hashes'] = template_hashes
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


      def cloud_properties
        if @availability_zone.nil?
          resource_pool.cloud_properties
        else
          @availability_zone.cloud_properties.merge(resource_pool.cloud_properties)
        end
      end

      def availability_zone_name
        return nil if @availability_zone.nil?

        @availability_zone.name
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
          model.compilation = @job.compilation?
          model.uuid = SecureRandom.uuid
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

      def log_changes(method_sym, old_state, new_state)
        @logger.debug("#{method_sym} changed FROM: #{old_state} TO: #{new_state}")
      end
    end
  end
end
