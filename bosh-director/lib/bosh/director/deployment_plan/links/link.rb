module Bosh::Director
  module DeploymentPlan
    # tested in links_resolver_spec

    class Link
      attr_reader :name

      def initialize(name, source, template, network_name = nil)
        @name = name
        @source = source
        @network_name = network_name
        @template = template
      end

      def spec
        {
          'available_networks' => @source.networks.map { |network| network.name },
          'instances' => @source.needed_instance_plans.map do |instance_plan|
            instance = instance_plan.instance
            availability_zone = instance.availability_zone.name if instance.availability_zone
            {
              'name' => @source.name,
              'index' => instance.index,
              'id' => instance.uuid,
              'az' => availability_zone,
              'address' => instance_plan.network_address(@network_name),
              'addresses' => instance_plan.network_addresses,
              'properties' => @template.provides_link_info(@source.name, @name)['properties']
            }
          end
        }
      end
    end
  end
end