require 'securerandom'

module Bosh::Director
  module DeploymentPlan
    # Represents a single Instance Group instance.
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

      # @return [Bosh::Director::Models::VariableSet]
      attr_accessor :desired_variable_set
      attr_reader :previous_variable_set

      # @return [String] job state
      attr_reader :virtual_state

      attr_reader :availability_zone

      attr_reader :existing_network_reservations

      def self.create_from_job(job, index, virtual_state, deployment_model, instance_state, availability_zone, logger)
        new(
          job.name,
          index,
          virtual_state,
          MergedCloudProperties.new(availability_zone, job.vm_type, job.vm_extensions).get,
          job.stemcell,
          job.env,
          job.compilation?,
          deployment_model,
          instance_state,
          availability_zone,
          logger
        )
      end

      def initialize(
        job_name,
        index,
        virtual_state,
        merged_cloud_properties,
        stemcell,
        env,
        compilation,
        deployment_model,
        instance_state,
        availability_zone,
        logger
      )
        @index = index
        @availability_zone = availability_zone
        @logger = logger
        @deployment_model = deployment_model
        @job_name = job_name
        @stemcell = stemcell
        @env = env
        @compilation = compilation
        @merged_cloud_properties = merged_cloud_properties

        @configuration_hash = nil
        @template_hashes = nil
        @vm = nil

        @desired_variable_set = nil
        @previous_variable_set = nil

        # This state is coming from the agent, we
        # only need networks and job_state from it.
        @current_state = instance_state || {}

        # reservation generated from current state/DB
        @existing_network_reservations = InstanceNetworkReservations.new(logger)

        @virtual_state = virtual_state
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
        if @uuid.nil?
          "#{@job_name}/#{@index}"
        else
          "#{@job_name}/#{@uuid} (#{@index})"
        end
      end

      def ensure_model_bound
        @model ||= find_or_create_model
      end

      def bind_new_instance_model
        @model = Models::Instance.create({
            deployment_id: @deployment_model.id,
            job: @job_name,
            index: index,
            state: state,
            compilation: @compilation,
            uuid: SecureRandom.uuid,
            availability_zone: availability_zone_name,
            bootstrap: false,
            variable_set_id: @deployment_model.current_variable_set.id
          })
        @uuid = @model.uuid
        @desired_variable_set = @model.variable_set
        @previous_variable_set = @model.variable_set
      end

      def stemcell
        @stemcell
      end

      def stemcell_cid
        @stemcell.cid_for_az(availability_zone_name)
      end

      def env
        @env.spec
      end

      def deployment_model
        @deployment_model
      end

      # Updates this domain object to reflect an existing instance running on an existing vm
      def bind_existing_instance_model(existing_instance_model)
        @uuid = existing_instance_model.uuid
        check_model_not_bound
        @model = existing_instance_model
        @desired_variable_set = existing_instance_model.variable_set
        @previous_variable_set = existing_instance_model.variable_set
      end

      def bind_existing_reservations(reservations)
        @existing_network_reservations = reservations
      end

      def apply_vm_state(spec)
        @logger.info('Applying VM state')

        @current_state = spec.full_spec
        agent_client.apply(spec.as_apply_spec)
        @model.update(spec: @current_state)
      end

      def apply_initial_vm_state(spec)
        # Agent will return dynamic network settings, we need to update spec with it
        # so that we can render templates with new spec later.
        agent_spec_keys = ['networks', 'deployment', 'job', 'index', 'id']
        agent_partial_state = spec.as_apply_spec.select { |k, _| agent_spec_keys.include?(k) }
        agent_client.apply(agent_partial_state)

        instance_spec_keys = agent_spec_keys + ['stemcell', 'vm_type', 'env']
        instance_partial_state = spec.full_spec.select { |k, _| instance_spec_keys.include?(k) }
        @current_state.merge!(instance_partial_state)

        agent_state = agent_client.get_state
        unless agent_state.nil?
          @current_state['networks'] = agent_state['networks']
          @model.update(spec: @current_state)
        end
      end

      def update_instance_settings
        disk_associations = @model.reload.active_persistent_disks.collection.select do |disk|
          !disk.model.managed?
        end
        disk_associations.map! do |disk|
           {'name' => disk.model.name, 'cid' => disk.model.disk_cid}
        end

        agent_client.update_settings(Config.trusted_certs, disk_associations)
        @model.active_vm.update(:trusted_certs_sha1 => ::Digest::SHA1.hexdigest(Config.trusted_certs))
      end

      def update_cloud_properties!
        @model.update(cloud_properties: JSON.dump(cloud_properties))
      end

      def agent_client
        AgentClient.with_vm_credentials_and_agent_id(@model.credentials, @model.agent_id)
      end

      def cloud_properties_changed?
        config_server_client_factory = Bosh::Director::ConfigServer::ClientFactory.create(@logger)
        config_server_client = config_server_client_factory.create_client

        proposed = config_server_client.interpolate_with_versioning(cloud_properties, @desired_variable_set)
        existing = config_server_client.interpolate_with_versioning(@model.cloud_properties_hash, @previous_variable_set)

        @cloud_properties_changed = existing != proposed
        log_changes(__method__, @model.cloud_properties_hash, cloud_properties) if @cloud_properties_changed

        @cloud_properties_changed
      end

      def current_job_spec
        @model.spec_p('job')
      end

      def current_packages
        @model.spec_p('packages')
      end

      def current_job_state
        @current_state['job_state']
      end

      def current_networks
        @current_state['networks']
      end

      def update_state
        @model.update(state: state)
      end

      def dirty?
        !@model.update_completed
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

      def assign_availability_zone_and_update_cloud_properties(availability_zone, vm_type, vm_extensions)
        @availability_zone = availability_zone
        @merged_cloud_properties = MergedCloudProperties.new(availability_zone, vm_type, vm_extensions).get
        @model.update(availability_zone: availability_zone_name)
      end

      def update_variable_set
        @model.update(variable_set: @desired_variable_set)
      end

      def state
        case @virtual_state
          when 'recreate'
            'started'
          when 'restart'
            'started'
          else
            @virtual_state
        end
      end

      ##
      # Checks if the target VM already has the same set of trusted SSL certificates
      # as the director currently wants to install on all managed VMs. This will
      # differ for VMs that existed before the director's configuration changed.
      #
      # @return [Boolean] true if the VM needs to be sent a new set of trusted certificates
      def trusted_certs_changed?
        config_trusted_certs = ::Digest::SHA1.hexdigest(Bosh::Director::Config.trusted_certs)
        changed = config_trusted_certs != @model.trusted_certs_sha1
        log_changes(__method__, @model.trusted_certs_sha1, config_trusted_certs) if changed
        changed
      end

      def vm_created?
        !@model.active_vm.nil?
      end

      def cloud_properties
        @merged_cloud_properties
      end

      def availability_zone_name
        return nil if @availability_zone.nil?

        @availability_zone.name
      end

      def update_templates(templates)
        transactor = Transactor.new
        transactor.retryable_transaction(Bosh::Director::Config.db) do
          @model.remove_all_templates
          templates.map(&:model).each do |template_model|
            @model.add_template(template_model)
          end
        end
      end

      private
      # Looks up instance model in DB
      # @return [Models::Instance]
      def find_or_create_model
        if @deployment_model.nil?
          raise DirectorError, 'Deployment model is not bound'
        end

        conditions = {
          deployment_id: @deployment_model.id,
          job: @job_name,
          index: @index
        }

        Models::Instance.find_or_create(conditions) do |model|
          model.state = 'started'
          model.compilation = @compilation
          model.uuid = SecureRandom.uuid
          model.variable_set_id = @deployment_model.current_variable_set.id
        end
      end

      # @param [Hash] network_settings map of network name to settings
      # @return [Hash] map of network name to IP address
      def network_to_ip(network_settings)
        Hash[network_settings.map { |network_name, settings| [network_name, settings['ip']] }]
      end

      def check_model_bound
        if @model.nil?
          raise DirectorError, "Instance '#{self}' model is not bound"
        end
      end

      def check_model_not_bound
        raise DirectorError, "Instance '#{self}' model is already bound" if @model
      end

      def log_changes(method_sym, old_state, new_state)
        @logger.debug("#{method_sym} changed FROM: #{old_state} TO: #{new_state}")
      end
    end
  end
end
