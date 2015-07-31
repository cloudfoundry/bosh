# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module DeploymentPlan
    ##
    # Represents a logical deployment network.
    class Network
      include DnsHelper
      include ValidationHelper

      VALID_DEFAULTS = %w(dns gateway).sort

      # @return [String] network name
      attr_accessor :name

      # @return [String] canonical network name
      attr_accessor :canonical_name

      ##
      # Creates a new network.
      #
      # @param [DeploymentPlan] deployment associated deployment plan
      # @param [Hash] network_spec parsed deployment manifest network section
      def initialize(network_spec, logger)
        @name = safe_property(network_spec, "name", :class => String)
        @canonical_name = canonical(@name)
        @logger = logger
      end

      ##
      # Reserves a network resource.
      #
      # Will update the passed in reservation if it can be fulfilled.
      # @param [NetworkReservation] reservation
      # @return [Boolean] true if the reservation was fulfilled
      def reserve(reservation)
        raise NotImplementedError, "#reserve not implemented for #{self.class}"
      end

      ##
      # Releases a previous reservation that had been fulfilled.
      # @param [NetworkReservation] reservation
      # @return [void]
      def release(reservation)
        raise NotImplementedError, "#release not implemented for #{self.class}"
      end

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = VALID_DEFAULTS)
        raise NotImplementedError,
              "#network_settings not implemented for #{self.class}"
      end

      def subnet_azs_contained_in(availability_zones)
        raise NotImplementedError
      end

      def validate_has_job!(az_names, job_name)
        raise NotImplementedError
      end
    end
  end
end
