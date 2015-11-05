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

      def subnet_azs_contained_in(availability_zones)
        raise NotImplementedError
      end

      def validate_has_job!(az_names, job_name)
        raise NotImplementedError
      end

      def validate_reference_from_job!(job_network_spec)
      end
    end

    class NetworkWithSubnets < Network
      def validate_has_job!(job_az_names, job_name)
        if job_az_names.nil? && !any_subnet_without_az?
          raise JobNetworkMissingRequiredAvailabilityZone,
            "Job '#{job_name}' must specify availability zone that matches availability zones of network '#{@name}'."
        end

        unreferenced_zones = job_az_names.to_a - availability_zones
        unless unreferenced_zones.empty?
          raise Bosh::Director::JobNetworkMissingRequiredAvailabilityZone,
            "Job '#{job_name}' refers to an availability zone(s) '#{unreferenced_zones}' but '#{@name}' has no matching subnet(s)."
        end
      end

      def availability_zones
        @subnets.map(&:availability_zone_names).flatten.compact.uniq
      end

      def any_subnet_without_az?
        @subnets.empty? || @subnets.any? { |subnet| subnet.availability_zone_names.nil? }
      end
    end
  end
end
