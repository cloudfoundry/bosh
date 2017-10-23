module Bosh::Director
  module DeploymentPlan
    class DeploymentFeatures
      attr_reader :use_dns_addresses
      attr_reader :use_short_dns_addresses
      attr_reader :randomize_az_placement

      def initialize(use_dns_addresses = nil, use_short_dns_addresses = nil, randomize_az_placement = nil)
        @use_dns_addresses = use_dns_addresses
        @use_short_dns_addresses = use_short_dns_addresses
        @randomize_az_placement = randomize_az_placement
      end
    end
  end
end
