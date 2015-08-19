module Bosh::Director
  module DeploymentPlan
    class DynamicNetworkSubnet
      def initialize(dns, cloud_properties, availability_zone)
        @dns = dns
        @cloud_properties = cloud_properties
        @availability_zone = availability_zone
      end

      attr_reader :dns, :cloud_properties, :availability_zone
    end
  end
end
