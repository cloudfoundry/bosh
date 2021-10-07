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

      attr_reader :instance_group_name

      attr_reader :stemcell

      attr_reader :deployment_model

      def self.create_from_instance_group(instance_group, index, virtual_state, deployment_model, instance_state, az, logger, variables_interpolator)
        new(
          instance_group.name,
          index,
          virtual_state,
          MergedCloudProperties.new(az, instance_group.vm_type, instance_group.vm_extensions).get,
          instance_group.stemcell,
          instance_group.env,
          instance_group.compilation?,
          deployment_model,
          instance_state,
          az,
          logger,
          variables_interpolator,
        )
      end

      def initialize(instance_group_name,
                     index,
                     virtual_state,
                     merged_cloud_properties,
                     stemcell,
                     env,
                     compilation,
                     deployment_model,
                     instance_state,
                     availability_zone,
                     logger,
                     variables_interpolator)
        @index = index
        @availability_zone = availability_zone
        @logger = logger
        @deployment_model = deployment_model
        @instance_group_name = instance_group_name
        @stemcell = stemcell
        @env = env
        @compilation = compilation
        @merged_cloud_properties = merged_cloud_properties

        @configuration_hash = nil
        @template_hashes = nil

        @desired_variable_set = nil
        @previous_variable_set = nil

        # This state is coming from the agent, we
        # only need networks and job_state from it.
        @current_state = instance_state || {}

        # reservation generated from current state/DB
        @existing_network_reservations = InstanceNetworkReservations.new(logger)

        @virtual_state = virtual_state
        @variables_interpolator = variables_interpolator
      end

      def bootstrap?
        @model&.bootstrap
      end

      def compilation?
        @compilation
      end

      def is_deploy_action?
        @is_deploy_action
      end

      attr_writer :is_deploy_action

      def to_s
        if @uuid.nil?
          "#{@instance_group_name}/#{@index}"
        else
          "#{@instance_group_name}/#{@uuid} (#{@index})"
        end
      end

      def ensure_model_bound
        @model ||= find_or_create_model
      end

      def bind_new_instance_model
        @model = Models::Instance.create(
          deployment_id: @deployment_model.id,
          job: @instance_group_name,
          index: index,
          state: state,
          compilation: @compilation,
          uuid: SecureRandom.uuid,
          availability_zone: availability_zone_name,
          bootstrap: false,
          variable_set_id: @deployment_model.current_variable_set.id,
        )
        @uuid = @model.uuid
        @desired_variable_set = @model.variable_set
        @previous_variable_set = @model.variable_set
      end

      def env
        @env.spec
      end

      # Updates this domain object to reflect an existing instance running on an existing vm
      def bind_existing_instance_model(existing_instance_model)
        @uuid = existing_instance_model.uuid
        check_model_not_bound
        @model = existing_instance_model
        @desired_variable_set = @deployment_model.last_successful_variable_set || @deployment_model.current_variable_set
        @previous_variable_set = existing_instance_model.variable_set
      end

      def bind_existing_reservations(reservations)
        @existing_network_reservations = reservations
      end

      def apply_vm_state(spec)
        @logger.info('Applying VM state')

        @current_state = spec.full_spec

        apply_spec = Bosh::Common::DeepCopy.copy(spec.as_apply_spec)

        blobstore = App.instance.blobstores.blobstore
        if blobstore.can_sign_urls?(@stemcell.api_version) && !!apply_spec['packages']
          apply_spec['packages'].each do |_, package|
            package['signed_url'] = blobstore.sign(package['blobstore_id'], 'get')
            package['blobstore_headers'] = blobstore.signed_url_encryption_headers if blobstore.encryption?
          end
        end

        agent_client.apply(apply_spec)
        @model.update(spec: @current_state)
      end

      def add_state_to_model(state)
        @current_state.merge!(state)
        @model.update(spec: @current_state)
      end

      def update_instance_settings(vm)
        disk_associations = @model.reload.active_persistent_disks.collection.reject do |disk|
          disk.model.managed?
        end

        disk_associations.map! do |disk|
          { 'name' => disk.model.name, 'cid' => disk.model.disk_cid }
        end

        settings = {
          'trusted_certs' => Config.trusted_certs,
          'disk_associations' => disk_associations,
        }
        if blobstore_config_changed?
          blobstore = App.instance.blobstores.blobstore
          blobstore.validate!(Config.agent_env['blobstores'].first.fetch('options', {}), @stemcell.api_version)
          if blobstore.can_sign_urls?(@stemcell.api_version)
            settings['blobstores'] = blobstore.redact_credentials(Config.agent_env['blobstores'])
          else
            settings['blobstores'] = Config.agent_env['blobstores']
          end
        end

        if nats_config_changed?
          cert_generator = NatsClientCertGenerator.new(@logger)
          agent_cert_key_result = cert_generator.generate_nats_client_certificate "#{vm.agent_id}.agent.bosh-internal"
          settings['mbus'] = {
            'cert' => {
              'ca' => Config.nats_server_ca,
              'certificate' => agent_cert_key_result[:cert].to_pem,
              'private_key' => agent_cert_key_result[:key].to_pem,
            }
          }
        end

        # We have to create our own AgentClient rather than use the `agent_client` method here because the VM
        # we are updating the settings on might not be the active VM for the instance depending on deployment strategy
        AgentClient.with_agent_id(vm.agent_id, @model.name).update_settings(settings)
        vm.update(
          blobstore_config_sha1: Config.blobstore_config_fingerprint,
          nats_config_sha1: Config.nats_config_fingerprint,
          trusted_certs_sha1: ::Digest::SHA1.hexdigest(Config.trusted_certs),
        )
      end

      def update_cloud_properties!
        @model.update(cloud_properties: JSON.dump(cloud_properties))
      end

      def agent_client
        AgentClient.with_agent_id(@model.agent_id, @model.name)
      end

      def cloud_properties_changed?
        changed = @variables_interpolator.interpolated_versioned_variables_changed?(
          @model.cloud_properties_hash,
          cloud_properties,
          @previous_variable_set,
          @desired_variable_set
        )

        log_changes(__method__, @model.cloud_properties_hash, cloud_properties) if changed
        changed
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
        @model.update(job: instance_group_name, index: index)
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

      def blobstore_config_changed?
        blobstore_config_fingerprint = Bosh::Director::Config.blobstore_config_fingerprint
        if blobstore_config_fingerprint != @model.blobstore_config_sha1
          log_changes(__method__, @model.blobstore_config_sha1, blobstore_config_fingerprint)
          return true
        end
        false
      end

      def nats_config_changed?
        nats_config_fingerprint = Bosh::Director::Config.nats_config_fingerprint
        if nats_config_fingerprint != @model.nats_config_sha1
          log_changes(__method__, @model.nats_config_sha1, nats_config_fingerprint)
          return true
        end
        false
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

      def update_vm_cloud_properties(vm_cloud_properties)
        @merged_cloud_properties ||= {}
        @merged_cloud_properties.merge!(vm_cloud_properties)
      end

      private

      # Looks up instance model in DB
      # @return [Models::Instance]
      def find_or_create_model
        raise DirectorError, 'Deployment model is not bound' if @deployment_model.nil?

        conditions = {
          deployment_id: @deployment_model.id,
          job: @instance_group_name,
          index: @index,
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
        raise DirectorError, "Instance '#{self}' model is not bound" if @model.nil?
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
