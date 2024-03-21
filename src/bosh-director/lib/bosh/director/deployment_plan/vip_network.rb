module Bosh::Director
  module DeploymentPlan
    class VipNetwork < NetworkWithSubnets
      extend ValidationHelper
      include IpUtil

      # @return [Hash] Network cloud properties
      attr_reader :cloud_properties
      attr_reader :subnets

      def self.parse(network_spec, availability_zones, logger)
        name = safe_property(network_spec, 'name', class: String)

        subnets = safe_property(network_spec, 'subnets', class: Array, default: []).map do |subnet_spec|
          DeploymentPlan::VipNetworkSubnet.parse(subnet_spec, name, availability_zones)
        end

        cloud_properties = safe_property(network_spec, 'cloud_properties', class: Hash, default: {})
        new(name, cloud_properties, subnets, logger)
      end

      ##
      # Creates a new network.
      #
      # @param [Hash] network_spec parsed from the cloud config
      # @param [VipNetworkSubnet] vip network subnets parsed from the cloud config
      # @param [Logger] logger
      def initialize(name, cloud_properties, subnets, logger)
        super(name, logger)
        @cloud_properties = cloud_properties
        @subnets = subnets
        @logger = TaggedLogger.new(logger, 'network-configuration')
      end

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = REQUIRED_DEFAULTS, _availability_zone = nil)
        if default_properties && !default_properties.empty?
          raise NetworkReservationVipDefaultProvided,
                "Can't provide any defaults since this is a VIP network"
        end

        {
          'type' => 'vip',
          'ip' => ip_to_netaddr(reservation.ip).ip,
          'cloud_properties' => @cloud_properties,
        }
      end

      def vip?
        true
      end

      def ip_type(*)
        return :dynamic if globally_allocate_ip?

        :static
      end

      def globally_allocate_ip?
        !@subnets.empty?
      end

      def has_azs?(*)
        true
      end

      def find_az_names_for_ip(ip)
        subnet = @subnets.find { |sn| sn.static_ips.include?(ip) }

        subnet.availability_zone_names if subnet
      end
    end
  end
end
