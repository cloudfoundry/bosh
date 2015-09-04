module Bosh::Director
  module DeploymentPlan
    # tested in links_resolver_spec

    class Link
      attr_reader :name

      def initialize(name, source)
        @name = name
        @source = source
      end

      def spec
        {
          'nodes' => @source.instances.map do |instance|
            {
              'name' => @source.name,
              'index' => instance.index,
              'uuid' => instance.uuid,
              'networks' => network_spec(instance.network_settings)
            }
          end
        }
      end

      private

      def network_spec(network_settings)
        Hash[*network_settings.map do |name, settings|
          address = settings['type'] == 'dynamic' ? settings['dns_record_name'] : settings['ip']
          result = { 'address' => address }

          [name, result]
        end.flatten]
      end
    end
  end
end
