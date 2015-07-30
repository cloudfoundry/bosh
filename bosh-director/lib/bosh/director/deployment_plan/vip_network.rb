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
        super
        @cloud_properties = safe_property(network_spec, "cloud_properties",
          class: Hash, default: {})
        @reserved_ips = Set.new
        @logger = TaggedLogger.new(logger, 'network-configuration')
      end

      ##
      # Reserves a network resource.
      #
      # This is either an already used reservation being verified or a new one
      # waiting to be fulfilled.
      # @param [NetworkReservation] reservation
      # @return [Boolean] true if the reservation was fulfilled
      def reserve(reservation)
        reservation.reserved = false
        if reservation.ip.nil?
          @logger.error("Failed to reserve IP for vip network '#{@name}': IP must be provided")
          raise NetworkReservationIpMissing,
                "Must have IP for static reservations"
        end

        reservation.validate_type(NetworkReservation::STATIC)

        if @reserved_ips.include?(reservation.ip)
          raise Bosh::Director::NetworkReservationAlreadyInUse,
            "Failed to reserve IP '#{format_ip(reservation.ip)}' for vip network '#{@name}': IP already reserved"
        else
          @logger.debug("Reserving IP '#{format_ip(reservation.ip)}' for vip network '#{@name}'")
          reservation.reserved = true
          reservation.type = NetworkReservation::STATIC

          @reserved_ips.add(reservation.ip)
        end
        reservation.reserved?
      end

      ##
      # Releases a previous reservation that had been fulfilled.
      # @param [NetworkReservation] reservation
      # @return [void]
      def release(reservation)
        unless reservation.ip
          @logger.error("Failed to release IP for vip network '#{@name}': IP must be provided")
          raise NetworkReservationIpMissing,
                "Can't release reservation without an IP"
        end
        @logger.debug("Releasing IP '#{format_ip(reservation.ip)}' for vip network '#{@name}'")
        @reserved_ips.delete(reservation.ip)
      end

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = VALID_DEFAULTS)
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

      def validate!(availability_zones)
        # nothing to validate
      end
    end
  end
end
