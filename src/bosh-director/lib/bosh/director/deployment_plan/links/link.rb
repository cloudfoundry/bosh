module Bosh::Director
  module DeploymentPlan
    class Link
      attr_reader :name

      def initialize(deployment_name, name, source_instance_group, job)
        @deployment_name = deployment_name # Provider Deployment Name
        @name = name
        @source_instance_group = source_instance_group
        @job = job
      end

      def spec
        {
          'deployment_name' => @deployment_name,
          'domain' => Bosh::Director::Config.root_domain,
          'default_network' => @source_instance_group.default_network_name,
          'networks' => @source_instance_group.networks.map { |network| network.name },
          'instance_group' => @source_instance_group.name,
          'properties' => @job.provides_link_info(@source_instance_group.name, @name)['mapped_properties'],
          'instances' => @source_instance_group.needed_instance_plans.map do |instance_plan|
            instance = instance_plan.instance
            availability_zone = instance.availability_zone.name if instance.availability_zone
            {
              'name' => @source_instance_group.name,
              'id' => instance.uuid,
              'index' => instance.index,
              'bootstrap' => instance.bootstrap?,
              'az' => availability_zone,
              'address' => instance_plan.network_address,
              'addresses' => instance_plan.network_addresses(false),
              'dns_addresses' => instance_plan.network_addresses(true),
            }
          end
        }
      end
    end
  end
end
