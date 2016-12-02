module Bosh::Director
  module DeploymentPlan
    class VipNetwork < Network
      include IpUtil

      # @return [Hash] Network cloud properties
      attr_reader :cloud_properties

      ##
      # Creates a new network.
      #
      # @param [Hash] network_spec parsed deployment manifest network section
      # @param [Logger] logger
      def initialize(network_spec, logger)
        super(safe_property(network_spec, "name", :class => String), logger)

        @cloud_properties = safe_property(network_spec, "cloud_properties",
          class: Hash, default: {})
        @reserved_ips = Set.new
        @logger = TaggedLogger.new(logger, 'network-configuration')
      end

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = REQUIRED_DEFAULTS, availability_zone = nil)
        if default_properties && !default_properties.empty?
          raise NetworkReservationVipDefaultProvided,
                "Can't provide any defaults since this is a VIP network"
        end

        {
          "type" => "vip",
          "ip" => ip_to_netaddr(reservation.ip).ip,
          "cloud_properties" => @cloud_properties
        }
      end

      def ip_type(_)
        :static
      end

      def has_azs?(az_names)
        true
      end
    end
  end
end
