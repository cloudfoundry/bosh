module Bosh::Director
  module DeploymentPlan
    class Link
      attr_reader :name

      def initialize(provider_deployment_name, name, source_instance_group, job, network_options = {})
        @provider_deployment_name = provider_deployment_name # Provider Deployment Name
        @name = name
        @source_instance_group = source_instance_group
        @network_name = network_options.fetch(:preferred_network_name, nil)
        @enforce_ip = network_options.fetch(:enforce_ip, false)
        @job = job
      end

      def spec
        {
          'deployment_name' => @provider_deployment_name,
          'networks' => @source_instance_group.networks.map { |network| network.name },
          'properties' => @job.provides_link_info(@source_instance_group.name, @name)['mapped_properties'],
          'instances' => @source_instance_group.needed_instance_plans.map do |instance_plan|
            instance = instance_plan.instance
            availability_zone = instance.availability_zone.name if instance.availability_zone
            address = instance_plan.network_address(
              {
                :preferred_network_name => @network_name,
                :enforce_ip => @enforce_ip
              }
            )

            {
              'name' => @source_instance_group.name,
              'index' => instance.index,
              'bootstrap' => instance.bootstrap?,
              'id' => instance.uuid,
              'az' => availability_zone,
              'address' => address,
              'addresses' => instance_plan.network_addresses,
            }
          end
        }
      end
    end
  end
end