module Bosh::Director
  module DeploymentPlan
    class JobNetwork
      def initialize(name, static_ips, default_for, deployment_network)
        @name = name
        @static_ips = static_ips
        @default_for = default_for
        @deployment_network = deployment_network
      end

      attr_reader :name, :static_ips, :deployment_network

      def availability_zones
        @deployment_network.availability_zones
      end

      def properties_for_which_the_network_is_the_default
        @default_for
      end

      def default_for?(property)
        properties_for_which_the_network_is_the_default.include?(property)
      end

      def make_default_for(defaults)
        @default_for = defaults
      end
    end
  end
end
