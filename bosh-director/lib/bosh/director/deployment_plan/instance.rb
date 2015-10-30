require 'securerandom'

module Bosh::Director
  module DeploymentPlan
    # Represents a single job instance.
    class Instance

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

      def self.create_from_job(job, index, state, deployment, instance_state, availability_zone, logger)
        new(
          job.name,
          index,
          state,
          job.vm_type,
          job.stemcell,
          job.env,
          job.compilation?,
          deployment,
          instance_state,
          availability_zone,
          logger
        )
      end

      # Creates a new instance specification based on the job and index.
      # @param [DeploymentPlan::Job] job associated job
      # @param [Integer] index index for this instance
      def initialize(
        job_name,
        index,
        state,
        vm_type,
        stemcell,
        env,
        compilation,
        deployment,
        instance_state,
        availability_zone,
        logger
      )
        @index = index
        @availability_zone = availability_zone
        @logger = logger
        @deployment = deployment
        @job_name = job_name
        @name = "#{job_name}/#{@index}"
        @vm_type = vm_type
        @stemcell = stemcell
        @env = env
        @compilation = compilation

        @configuration_hash = nil
        @template_hashes = nil
        @vm = nil
        @current_state = instance_state || {}

        # reservation generated from current state/DB
        @existing_network_reservations = InstanceNetworkReservations.new(logger)
        @dns_manager = DnsManager.create

        @state = state
      end

      def bootstrap?
        @model && @model.bootstrap
      end

      def compilation?
        @compilation
      end

      def job_name
        @job_name
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
            job: @job_name,
            index: index,
            state: @state,
            compilation: @compilation,
            uuid: SecureRandom.uuid,
            bootstrap: false
          })
        @uuid = @model.uuid
      end

      def ensure_vm_allocated
        @uuid = @model.uuid
        if @model.vm.nil?
          allocate_vm
        end
      end

      def vm_type
        @vm_type
      end

      def stemcell
        @stemcell
      end

      def env
        @env.spec
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

      def apply_vm_state(apply_spec)
        @logger.info('Applying VM state')

        @current_state = apply_spec
        agent_client.apply(@current_state)
        @model.vm.update(:apply_spec => @current_state)
      end

      def apply_initial_vm_state(apply_spec)
        partial_state = {'networks' => apply_spec['networks']}
        agent_client.apply(partial_state)
        agent_state = agent_client.get_state
        unless agent_state.nil?
          @current_state['networks'] = agent_state['networks']
          @model.vm.update(:apply_spec => @current_state)
        end
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

      ##
      # @return [String] dns record name
      def dns_record_name(hostname, network_name)
        [hostname, job.canonical_name, Canonicalizer.canonicalize(network_name), Canonicalizer.canonicalize(deployment.name), @dns_manager.dns_domain_name].join('.')
      end

      def cloud_properties_changed?
        changed = cloud_properties != @model.cloud_properties_hash
        log_changes(__method__, @model.cloud_properties_hash, cloud_properties) if changed
        changed
      end

      ##
      # @return [Boolean] returns true if the expected configuration hash
      #   differs from the one provided by the VM
      def configuration_changed?
        changed = configuration_hash != @current_state['configuration_hash']
        log_changes(__method__, @current_state['configuration_hash'], configuration_hash) if changed
        changed
      end

      def current_job_spec
        @current_state['job']
      end

      def current_packages
        @current_state['packages']
      end

      def current_job_state
        @current_state['job_state']
      end

      def update_state
        @model.update(state: @state)
      end

      def update_description
        @model.update(job: job_name, index: index)
      end

      def mark_as_bootstrap
        @model.update(bootstrap: true)
      end

      def unmark_as_bootstrap
        @model.update(bootstrap: false)
      end

      def assign_availability_zone(availability_zone)
        @availability_zone = availability_zone
        @model.update(availability_zone: availability_zone_name)
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
          vm_type.cloud_properties
        else
          @availability_zone.cloud_properties.merge(vm_type.cloud_properties)
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
          job: @job_name,
          index: @index
        }

        Models::Instance.find_or_create(conditions) do |model|
          model.state = 'started'
          model.compilation = @compilation
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
