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
          'nodes' => @source.needed_instance_plans.map do |instance_plan|
            instance = instance_plan.instance
            availability_zone = instance.availability_zone.name if instance.availability_zone
            {
              'name' => @source.name,
              'index' => instance.index,
              'id' => instance.uuid,
              'az' => availability_zone,
              'networks' => instance_plan.network_addresses
            }
          end
        }
      end
    end
  end
end
