module Bosh::Director
  module DeploymentPlan
    class JobNetwork
      attr_reader :name, :static_ips, :deployment_network, :nic_group

      def initialize(name, static_ips, default_for, deployment_network, nic_group)
        @name = name
        @static_ips = static_ips
        @default_for = default_for
        @deployment_network = deployment_network
        @nic_group = nic_group&.to_i
      end

      def availability_zones
        @deployment_network.availability_zones
      end

      def properties_for_which_the_network_is_the_default
        @default_for
      end

      def static?
        Array(@static_ips).any? || vip?
      end

      def vip?
        deployment_network.is_a?(VipNetwork)
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
