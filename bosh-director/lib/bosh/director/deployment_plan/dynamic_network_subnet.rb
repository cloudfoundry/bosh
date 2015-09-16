module Bosh::Director
  module DeploymentPlan
    class DynamicNetworkSubnet
      def initialize(dns, cloud_properties, availability_zone_name)
        @dns = dns
        @cloud_properties = cloud_properties
        @availability_zone_name = availability_zone_name
      end

      attr_reader :dns, :cloud_properties, :availability_zone_name
    end
  end
end
