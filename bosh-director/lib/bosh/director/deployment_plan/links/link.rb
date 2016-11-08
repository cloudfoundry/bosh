module Bosh::Director
  module DeploymentPlan
    # tested in links_resolver_spec

    class Link
      attr_reader :name

      def initialize(deployment_name, name, source_instance_group, job, network_name = nil)
        @deployment_name = deployment_name # Provider Deployment Name
        @name = name
        @source_instance_group = source_instance_group
        @network_name = network_name
        @job = job
      end

      def spec
        {
          'deployment_name' => @deployment_name,
          'networks' => @source_instance_group.networks.map { |network| network.name },
          'properties' => @job.provides_link_info(@source_instance_group.name, @name)['mapped_properties'],
          'instances' => @source_instance_group.needed_instance_plans.map do |instance_plan|
            instance = instance_plan.instance
            availability_zone = instance.availability_zone.name if instance.availability_zone
            {
              'name' => @source_instance_group.name,
              'index' => instance.index,
              'bootstrap' => instance.bootstrap?,
              'id' => instance.uuid,
              'az' => availability_zone,
              'address' => instance_plan.network_address(@network_name),
              'addresses' => instance_plan.network_addresses,
            }
          end
        }
      end
    end
  end
end