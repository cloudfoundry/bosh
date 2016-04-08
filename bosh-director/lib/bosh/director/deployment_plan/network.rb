# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module DeploymentPlan
    ##
    # Represents a logical deployment network.
    class Network
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
      def initialize(name, logger)
        @name = name
        @canonical_name = Canonicalizer.canonicalize(@name)
        @logger = logger
      end

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = VALID_DEFAULTS, availability_zone = nil)
        raise NotImplementedError,
              "#network_settings not implemented for #{self.class}"
      end

      def has_azs?(az_names)
        raise NotImplementedError
      end

      def find_az_names_for_ip(ip)
        raise NotImplementedError
      end

      def validate_reference_from_job!(job_network_spec, job_name)
      end

      def supports_azs?
        false
      end

      def manual?
        false
      end
    end

    class NetworkWithSubnets < Network
      def has_azs?(az_names)
        az_names = [az_names].flatten

        if az_names.compact.empty? && availability_zones.empty?
          return true
        end

        unreferenced_zones = az_names - availability_zones
        if unreferenced_zones.empty?
          return true
        end

        false
      end

      def supports_azs?
        true
      end

      def availability_zones
        @subnets.map(&:availability_zone_names).flatten.uniq
      end
    end
  end
end
