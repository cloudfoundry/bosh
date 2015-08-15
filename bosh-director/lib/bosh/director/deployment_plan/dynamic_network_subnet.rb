module Bosh::Director
  module DeploymentPlan
    class DynamicNetworkSubnet
      def initialize(dns, cloud_properties)
        @dns = dns
        @cloud_properties = cloud_properties
      end

      attr_reader :dns, :cloud_properties
    end
  end
end
