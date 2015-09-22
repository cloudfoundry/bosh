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
            availability_zone = instance.availability_zone.name if instance.availability_zone
            {
              'name' => @source.name,
              'index' => instance.index,
              'id' => instance.uuid,
              'availability_zone' => availability_zone,
              'networks' => instance.network_addresses
            }
          end
        }
      end
    end
  end
end
