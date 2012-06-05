# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class DynamicNetworkSpec < NetworkSpec
      DYNAMIC_IP = NetAddr::CIDR.create("255.255.255.255").to_i

      attr_accessor :cloud_properties

      ##
      # Creates a new network.
      #
      # @param [DeploymentPlan] deployment associated deployment plan
      # @param [Hash] network_spec parsed deployment manifest network section
      def initialize(deployment, network_spec)
        super
        @cloud_properties = safe_property(network_spec, "cloud_properties",
                                          :class => Hash)
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
        if reservation.static?
          reservation.error = NetworkReservation::WRONG_TYPE
        else
          reservation.ip = DYNAMIC_IP
          reservation.reserved = true
          reservation.type = NetworkReservation::DYNAMIC
        end
        reservation.reserved?
      end

      ##
      # Releases a previous reservation that had been fulfilled.
      # @param [NetworkReservation] reservation
      # @return [void]
      def release(reservation)
        validate_ip(reservation)
      end

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = VALID_DEFAULTS)
        validate_ip(reservation)

        config = {
            "type" => "dynamic",
            "cloud_properties" => @cloud_properties
        }

        if default_properties
          config["default"] = default_properties.sort
        end

        config
      end

      private

      def validate_ip(reservation)
        unless reservation.ip == DYNAMIC_IP
          raise NetworkReservationInvalidIp,
                "Invalid IP: `%s', did not match magic DYNAMIC IP" % [
                  reservation.ip]
        end
      end
    end
  end
end