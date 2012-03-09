# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    ##
    # Represents a logical deployment network.
    class NetworkSpec
      include DnsHelper
      include ValidationHelper

      VALID_DEFAULTS = %w(dns gateway).sort

      # @return [DeploymentPlan] associated deployment
      attr_accessor :deployment

      # @return [String] network name
      attr_accessor :name

      # @return [String] canonical network name
      attr_accessor :canonical_name

      ##
      # Creates a new network.
      #
      # @param [DeploymentPlan] deployment associated deployment plan
      # @param [Hash] network_spec parsed deployment manifest network section
      def initialize(deployment, network_spec)
        @deployment = deployment
        @name = safe_property(network_spec, "name", :class => String)
        @canonical_name = canonical(@name)
      end

      ##
      # Reserves a network resource.
      #
      # Will update the passed in reservation if it can be fulfilled.
      # @param [NetworkReservation] reservation
      # @return [Boolean] true if the reservation was fulfilled
      def reserve(reservation)
        raise NotImplementedError
      end

      ##
      # Releases a previous reservation that had been fulfilled.
      # @param [NetworkReservation] reservation
      # @return [void]
      def release(reservation)
        raise NotImplementedError
      end

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = VALID_DEFAULTS)
        raise NotImplementedError
      end
    end
  end
end