module Bosh::Director
  module DeploymentPlan
    class InstanceFromDatabase
      attr_reader :model, :vm, :apply_spec

      def self.create_from_model(instance_model, logger)
        new(instance_model, logger)
      end

      def initialize(instance_model, logger)
        @model = instance_model
        @logger = logger

        @vm = Vm.new

        if @model.vm
          @vm.model = @model.vm
          @apply_spec = @model.vm.apply_spec
          @env = @model.vm.env
        else
          @apply_spec = {}
          @env = {}
        end
      end

      def job_name
        @model.job
      end

      def index
        @model.index
      end

      def to_s
        "#{job_name}/#{index}"
      end

      def deployment_model
        @model.deployment
      end

      def availability_zone_name
        @model.availability_zone
      end

      def cloud_properties
        @model.cloud_properties_hash
      end

      def resource_pool
        resource_pool_spec = @apply_spec.fetch('resource_pool', {})
        ExistingResourcePool.new(resource_pool_spec, @env)
      end

      def update_trusted_certs
        agent_client.update_settings(Config.trusted_certs)
        @model.vm.update(:trusted_certs_sha1 => Digest::SHA1.hexdigest(Config.trusted_certs))
      end

      def update_availability_zone!
        # since we loaded it from the DB there's no need to save it back
      end

      def take_old_reservations
        [] # nothing obsolete
      end

      def network_reservations
        [] # no one should care. we only use this outside of a deploy or for an obsolete instance plan
      end

      def update_cloud_properties!
        # since we loaded them from the DB there's no need to save them back
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
