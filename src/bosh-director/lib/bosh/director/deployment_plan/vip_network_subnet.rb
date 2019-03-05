module Bosh::Director
  module DeploymentPlan
    class VipNetworkSubnet < Subnet
      extend ValidationHelper
      extend IpUtil

      attr_reader :static_ips, :availability_zones

      def self.parse(subnet_spec, network_name, azs)
        static_ips = Set.new

        static_property = safe_property(subnet_spec, 'static', class: Array, default: [])
        each_ip(static_property) do |ip|
          static_ips.add(ip)
        end

        availability_zones = parse_availability_zones(subnet_spec, network_name, azs)

        new(static_ips, availability_zones)
      end

      def initialize(static_ips, availability_zones)
        @static_ips = static_ips
        @availability_zones = availability_zones
      end
    end
  end
end
