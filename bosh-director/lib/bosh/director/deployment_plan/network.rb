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
      def initialize(name, logger)
        @name = name
        @canonical_name = canonical(@name)
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

      def subnet_azs_contained_in(availability_zones)
        raise NotImplementedError
      end

      def validate_has_job!(az_names, job_name)
        raise NotImplementedError
      end
    end

    class NetworkWithSubnets < Network
      def validate_has_job!(az_names, job_name)
        unreferenced_zones = az_names - availability_zones
        unless unreferenced_zones.empty?
          raise Bosh::Director::JobNetworkMissingRequiredAvailabilityZone,
            "Job '#{job_name}' refers to an availability zone(s) '#{unreferenced_zones}' but '#{@name}' has no matching subnet(s)."
        end
      end

      def availability_zones
        @subnets.map(&:availability_zone_names).flatten.compact.uniq
      end
    end
  end
end
