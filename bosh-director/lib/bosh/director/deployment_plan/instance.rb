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
      attr_reader :virtual_state

      attr_reader :availability_zone

      attr_reader :existing_network_reservations

      def self.create_from_job(job, index, virtual_state, deployment_model, instance_state, availability_zone, logger)
        new(
          job.name,
          index,
          virtual_state,
          job.vm_type,
          job.vm_extensions,
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
        vm_type,
        vm_extensions,
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
        @vm_type = vm_type
        @vm_extensions = vm_extensions
        @stemcell = stemcell
        @env = env
        @compilation = compilation

        @configuration_hash = nil
        @template_hashes = nil
        @vm = nil

        # This state is coming from the agent, we
        # only need networks and job_state from it.
        @current_state = instance_state || {}

        # reservation generated from current state/DB
        @existing_network_reservations = InstanceNetworkReservations.new(logger)
        @dns_manager = DnsManagerProvider.create

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
          "#{@job_name}/#{@index} (#{@uuid})"
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
            bootstrap: false
          })
        @uuid = @model.uuid
      end

      def vm_type
        @vm_type
      end

      def vm_extensions
        @vm_extensions
      end

      def stemcell
        @stemcell
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

      def update_trusted_certs
        agent_client.update_settings(Config.trusted_certs)
        @model.update(:trusted_certs_sha1 => Digest::SHA1.hexdigest(Config.trusted_certs))
      end

      def update_cloud_properties!
        @model.update(cloud_properties: JSON.dump(cloud_properties))
      end

      def agent_client
        AgentClient.with_vm_credentials_and_agent_id(@model.credentials, @model.agent_id)
      end

      ##
      # @return [String] dns record name
      def dns_record_name(hostname, network_name)
        [hostname, job.canonical_name, Canonicalizer.canonicalize(network_name), Canonicalizer.canonicalize(@deployment_model.name), @dns_manager.dns_domain_name].join('.')
      end

      def cloud_properties_changed?
        changed = cloud_properties != @model.cloud_properties_hash
        log_changes(__method__, @model.cloud_properties_hash, cloud_properties) if changed
        changed
      end

      def current_job_spec
        @model.spec['job']
      end

      def current_packages
        @model.spec['packages']
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

      def assign_availability_zone(availability_zone)
        @availability_zone = availability_zone
        @model.update(availability_zone: availability_zone_name)
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
        config_trusted_certs = Digest::SHA1.hexdigest(Bosh::Director::Config.trusted_certs)
        changed = config_trusted_certs != @model.trusted_certs_sha1
        log_changes(__method__, @model.trusted_certs_sha1, config_trusted_certs) if changed
        changed
      end

      def vm_created?
        !@model.vm_cid.nil?
      end

      def cloud_properties
        merged_cloud_properties = nil

        if !@availability_zone.nil?
          merged_cloud_properties = merge_cloud_properties(merged_cloud_properties, @availability_zone.cloud_properties)
        end

        merged_cloud_properties = merge_cloud_properties(merged_cloud_properties, vm_type.cloud_properties)

        Array(vm_extensions).each do |vm_extension|
          merged_cloud_properties = merge_cloud_properties(merged_cloud_properties, vm_extension.cloud_properties)
        end

        merged_cloud_properties
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

      def merge_cloud_properties(merged_cloud_properties, new_cloud_properties)
        merged_cloud_properties.nil? ? new_cloud_properties : merged_cloud_properties.merge(new_cloud_properties)
      end

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
