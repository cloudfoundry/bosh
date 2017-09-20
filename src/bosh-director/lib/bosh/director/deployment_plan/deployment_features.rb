module Bosh::Director
  module DeploymentPlan
    class DeploymentFeatures
      attr_reader :use_dns_addresses
      attr_reader :use_short_dns_addresses

      def initialize(use_dns_addresses = nil, use_short_dns_addresses = nil)
        @use_dns_addresses = use_dns_addresses
        @use_short_dns_addresses = use_short_dns_addresses
      end
    end
  end
end
