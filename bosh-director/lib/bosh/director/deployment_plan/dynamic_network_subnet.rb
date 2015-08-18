module Bosh::Director
  module DeploymentPlan
    class DynamicNetworkSubnet
      def initialize(dns, cloud_properties, availability_zone_name)
        @dns = dns
        @cloud_properties = cloud_properties
        @availability_zone_name = availability_zone_name
      end

      attr_reader :dns, :cloud_properties

      def validate!(availability_zones)
        @availability_zone_name.assert_present!(availability_zones)
      end

      def availability_zone
        @availability_zone_name.name
      end
    end
  end
end
