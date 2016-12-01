module Bosh::Director
  module DeploymentPlan
    ##
    # Represents a explicitly configured network.
    class ManualNetwork < NetworkWithSubnets
      extend ValidationHelper
      include IpUtil

      attr_reader :subnets

      def self.parse(network_spec, availability_zones, global_network_resolver, logger)
        name = safe_property(network_spec, "name", :class => String)

        reserved_ranges = global_network_resolver.reserved_ranges
        subnet_specs = safe_property(network_spec, 'subnets', :class => Array)
        subnets = []
        subnet_specs.each do |subnet_spec|
          new_subnet = ManualNetworkSubnet.parse(name, subnet_spec, availability_zones, reserved_ranges)
          subnets.each do |subnet|
            if subnet.overlaps?(new_subnet)
              raise NetworkOverlappingSubnets, "Network '#{name}' has overlapping subnets"
            end
          end
          subnets << new_subnet
        end
        validate_all_subnets_use_azs(subnets, name)
        new(name, subnets, logger)
      end

      def initialize(name, subnets, logger)
        super(name, TaggedLogger.new(logger, 'network-configuration'))
        @subnets = subnets
      end

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = REQUIRED_DEFAULTS, availability_zone = nil)
        unless reservation.ip
          raise NetworkReservationIpMissing,
                "Can't generate network settings without an IP"
        end

        ip = ip_to_netaddr(reservation.ip)
        subnet = find_subnet_containing(reservation.ip)
        unless subnet
          raise NetworkReservationInvalidIp, "Provided IP '#{ip}' does not belong to any subnet"
        end

        config = {
          "type" => "manual",
          "ip" => ip.ip,
          "netmask" => subnet.netmask,
          "cloud_properties" => subnet.cloud_properties
        }

        if default_properties
          config["default"] = default_properties.sort
        end

        config["dns"] = subnet.dns if subnet.dns
        config["gateway"] = subnet.gateway.ip if subnet.gateway
        config
      end

      def ip_type(cidr_ip)
        static_ips = @subnets.map { |subnet| subnet.static_ips.to_a }.flatten
        static_ips.include?(cidr_ip.to_i) ? :static : :dynamic
      end

      def find_az_names_for_ip(ip)
        subnet = find_subnet_containing(ip)
        if subnet
          return subnet.availability_zone_names
        end
      end

      def manual?
        true
      end

      # @param [Integer, NetAddr::CIDR, String] ip
      # @yield the subnet that contains the IP.
      def find_subnet_containing(ip)
        @subnets.find { |subnet| subnet.range.contains?(ip) }
      end

      private

      def self.validate_all_subnets_use_azs(subnets, network_name)
        subnets_with_azs = []
        subnets_without_azs = []
        subnets.each do |subnet|
          if subnet.availability_zone_names.to_a.empty?
            subnets_without_azs << subnet
          else
            subnets_with_azs << subnet
          end
        end

        if subnets_with_azs.size > 0 && subnets_without_azs.size > 0
          raise JobInvalidAvailabilityZone,
            "Subnets on network '#{network_name}' must all either specify availability zone or not"
        end
      end
    end
  end
end
