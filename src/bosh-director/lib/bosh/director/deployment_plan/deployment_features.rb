module Bosh::Director
  module DeploymentPlan
    class DeploymentFeatures
      attr_reader :use_dns_addresses

      def initialize(use_dns_addresses = nil)
        @use_dns_addresses = use_dns_addresses
      end
    end
  end
end
