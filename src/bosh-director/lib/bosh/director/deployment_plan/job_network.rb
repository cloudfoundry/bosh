module Bosh::Director
  module DeploymentPlan
    class JobNetwork
      attr_reader :name, :static_ips, :deployment_network

      def initialize(name, static_ips, default_for, deployment_network)
        @name = name
        @static_ips = static_ips
        @default_for = default_for
        @deployment_network = deployment_network
      end

      def availability_zones
        @deployment_network.availability_zones
      end

      def properties_for_which_the_network_is_the_default
        @default_for
      end

      def static?
        !!@static_ips
      end

      def vip?
        deployment_network.kind_of?(VipNetwork)
      end

      def default_for?(property)
        properties_for_which_the_network_is_the_default.include?(property)
      end

      def make_default_for(defaults)
        @default_for = defaults
      end

      def has_azs?(az_names)
        @deployment_network.has_azs?(az_names)
      end
    end
  end
end
