module Bosh::Director
  module DeploymentPlan
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
        instance_plan = @source_instance_group.needed_instance_plans.first
        if instance_plan
          root_domain = instance_plan.root_domain
        else
          root_domain = Bosh::Director::Config.root_domain
        end

        if @network_name.nil?
          if @source_instance_group.default_network.has_key?('addressable')
            network = @source_instance_group.default_network['addressable']
          else
            network = @source_instance_group.default_network['gateway']
          end
        else
          network = @network_name
        end

        {
          'deployment_name' => @deployment_name,
          'domain' => root_domain,
          'default_network' => network,
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
