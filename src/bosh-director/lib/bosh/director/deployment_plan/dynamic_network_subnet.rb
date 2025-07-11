module Bosh::Director
  module DeploymentPlan
    class DynamicNetworkSubnet
      def initialize(dns, cloud_properties, availability_zone_names, prefix)
        @dns = dns
        @cloud_properties = cloud_properties
        @availability_zone_names = availability_zone_names.nil? ? nil : availability_zone_names
        @prefix = prefix.to_s
      end

      attr_reader :dns, :cloud_properties, :availability_zone_names, :prefix
    end
  end
end
