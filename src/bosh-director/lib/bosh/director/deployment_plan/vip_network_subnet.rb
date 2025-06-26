module Bosh::Director
  module DeploymentPlan
    class VipNetworkSubnet < Subnet
      extend ValidationHelper
      extend IpUtil

      attr_reader :static_ips, :availability_zone_names, :prefix

      def self.parse(subnet_spec, network_name, azs)
        static_ips = Set.new

        prefix = safe_property(subnet_spec, 'prefix', optional: true)
        if prefix.nil?
          prefix = "32"
        end

        static_property = safe_property(subnet_spec, 'static', class: Array, default: [])
        each_ip(static_property) do |ip|
          static_ips.add(ip)
        end

        availability_zone_names = parse_availability_zones(subnet_spec, network_name, azs)

        new(static_ips, availability_zone_names, prefix)
      end

      def initialize(static_ips, availability_zone_names, prefix)
        @static_ips = static_ips
        @availability_zone_names = availability_zone_names
        @prefix = prefix.to_s
      end

      def is_reservable?(ip)
        @static_ips.include?(ip.to_i)
      end
    end
  end
end
