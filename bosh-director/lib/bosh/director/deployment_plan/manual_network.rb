module Bosh::Director
  module DeploymentPlan
    ##
    # Represents a explicitly configured network.
    class ManualNetwork < Network
      include IpUtil
      include DnsHelper
      include ValidationHelper

      attr_reader :subnets

      ##
      # Creates a new network.
      #
      # @param [Hash] network_spec parsed deployment manifest network section
      # @param [DeploymentPlan::GlobalNetworkResolver] global_network_resolver
      # @param [Logger] logger
      def initialize(network_spec, availability_zones, global_network_resolver, logger)
        super(network_spec, logger)

        reserved_ranges = global_network_resolver.reserved_legacy_ranges(@name)
        subnet_specs = safe_property(network_spec, 'subnets', :class => Array)

        @subnets = []
        subnet_specs.each do |subnet_spec|
          new_subnet = ManualNetworkSubnet.new(self, subnet_spec, availability_zones, reserved_ranges)
          @subnets.each do |subnet|
            if subnet.overlaps?(new_subnet)
              raise NetworkOverlappingSubnets, "Network `#{name}' has overlapping subnets"
            end
          end
          @subnets << new_subnet
        end

        @default_subnet = ManualNetworkSubnet.new(
          self,
          {'range' => '0.0.0.0/0', 'gateway' => '0.0.0.1'},
          [],
          []
        )

        @logger = TaggedLogger.new(logger, 'network-configuration')
      end

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = VALID_DEFAULTS)
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

      # @param [Integer, NetAddr::CIDR, String] ip
      # @yield the subnet that contains the IP.
      def find_subnet_containing(ip)
        @subnets.find { |subnet| subnet.range.contains?(ip) }
      end

      def availability_zones
        @subnets.map(&:availability_zone).compact.uniq
      end

      def validate_has_job!(az_names, job_name)
        unreferenced_zones = az_names - availability_zones
        unless unreferenced_zones.empty?
          raise Bosh::Director::JobNetworkMissingRequiredAvailabilityZone,
            "Job '#{job_name}' refers to an availability zone(s) '#{unreferenced_zones}' but '#{@name}' has no matching subnet(s)."
        end
      end
    end
  end
end
