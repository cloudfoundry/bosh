module Bosh::Director
  module DeploymentPlan
    class Link
      attr_reader :provider_deployment_name
      attr_reader :provider_name, :provider_type
      attr_reader :source_instance_group

      def initialize(
        provider_deployment_name,
        provider_name,
        provider_type,
        source_instance_group,
        mapped_properties,
        use_dns_addresses,
        use_short_dns_addresses,
        use_link_dns_names
      )
        @provider_deployment_name = provider_deployment_name
        @provider_name = provider_name
        @provider_type = provider_type
        @source_instance_group = source_instance_group
        @mapped_properties = mapped_properties
        @use_dns_addresses = use_dns_addresses
        @use_short_dns_addresses = use_short_dns_addresses
        @use_link_dns_names = use_link_dns_names
      end

      def spec
        {
          'deployment_name' => @provider_deployment_name,
          'domain' => Bosh::Director::Config.root_domain,
          'default_network' => @source_instance_group.default_network_name,
          'networks' => @source_instance_group.networks.map(&:name),
          'instance_group' => @source_instance_group.name,
          'properties' => @mapped_properties,
          'use_short_dns_addresses' => @use_short_dns_addresses,
          'use_dns_addresses' => @use_dns_addresses,
          'use_link_dns_names' => @use_link_dns_names,
          'instances' => @source_instance_group.needed_instance_plans.map do |instance_plan|
            instance = instance_plan.instance
            availability_zone = instance.availability_zone.name if instance.availability_zone
            {
              'name' => @source_instance_group.name,
              'id' => instance.uuid,
              'index' => instance.index,
              'bootstrap' => instance.bootstrap?,
              'az' => availability_zone,
              'address' => instance_plan.link_network_address(self),
              'addresses' => instance_plan.link_network_addresses(self, false),
              'dns_addresses' => instance_plan.link_network_addresses(self, true),
            }
          end,
        }
      end
    end
  end
end
