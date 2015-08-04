module Bosh::Director
  module DeploymentPlan
    class ExistingInstance
      attr_reader :model, :vm

      def self.create_from_model(instance_model, logger)
        deployment_model = instance_model.deployment
        cloud_config_model = deployment_model.cloud_config

        deployment_manifest_migrator = Bosh::Director::DeploymentPlan::ManifestMigrator.new
        manifest_hash = Psych.load(deployment_model.manifest)
        _, cloud_manifest = deployment_manifest_migrator.migrate(manifest_hash, cloud_config_model)

        # FIXME: we just want to figure out AZs, we don't care about subnets being able to reserve IPs
        ip_provider_factory = NullIpProviderFactory.new
        global_network_resolver = NullGlobalNetworkResolver.new

        cloud_manifest_parser = CloudManifestParser.new(logger)
        cloud_planner = cloud_manifest_parser.parse(cloud_manifest, ip_provider_factory, global_network_resolver)

        availability_zone = cloud_planner.availability_zone(instance_model.availability_zone)
        new(instance_model, availability_zone, logger)
      end

      def initialize(instance_model, availability_zone, logger)
        @model = instance_model
        @logger = logger
        @availability_zone = availability_zone

        @vm = Vm.new
        @vm.model = @model.vm

        @apply_spec = @model.vm.apply_spec
        @env = @model.vm.env
        @network_reservations = {}
      end

      attr_reader :availability_zone

      def job_name
        @model.job
      end

      def index
        @model.index
      end

      def deployment_model
        @model.deployment
      end

      def bind_state(deployment, state)
        @network_reservations = StateNetworkReservations.new(deployment).create_from_state(self, state)
      end

      def resource_pool
        resource_pool_spec = @apply_spec.fetch('resource_pool', {})
        ExistingResourcePool.new(resource_pool_spec, @env)
      end

      def update_trusted_certs
        agent_client.update_settings(Config.trusted_certs)
        @model.vm.update(:trusted_certs_sha1 => Digest::SHA1.hexdigest(Config.trusted_certs))
      end

      def update_availability_zone
        if @availability_zone.nil?
          @model.update(availability_zone: nil)
        else
          @model.update(availability_zone: @availability_zone.name)
        end
      end

      def apply_vm_state
        @logger.info('Applying VM state')
        @model.vm.update(:apply_spec => @apply_spec)
        agent_client.apply(@apply_spec)
      end

      def network_settings
        @apply_spec['networks']
      end

      def bind_to_vm_model(vm_model)
        @model.update(vm: vm_model)
        @vm.model = vm_model
      end

      def delete
        @network_reservations.each do |reservation|
          reservation.release if reservation.reserved?
        end
        @network_reservations = []

        @model.destroy
      end

      private

      def agent_client
        @agent_client ||= AgentClient.with_vm(@model.vm)
      end

      class ExistingResourcePool
        attr_reader :env

        def initialize(spec, env)
          @spec = spec
          @env = env
        end

        def stemcell
          stemcell_spec = @spec.fetch('stemcell', {})

          name = stemcell_spec['name']
          version = stemcell_spec['version']

          unless name && version
            raise 'Unknown stemcell name and/or version'
          end

          stemcell_manager = Api::StemcellManager.new
          stemcell_manager.find_by_name_and_version(name, version)
        end

        def cloud_properties
          @spec.fetch('cloud_properties', {})
        end
      end
    end
  end
end
