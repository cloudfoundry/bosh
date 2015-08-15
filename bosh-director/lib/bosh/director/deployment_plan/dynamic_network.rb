# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module DeploymentPlan
    class DynamicNetwork < Network
      include DnsHelper
      extend DnsHelper
      extend ValidationHelper

      def self.parse(network_spec, logger)
        if network_spec.has_key?('subnets')
          if network_spec.has_key?('dns')
            raise NetworkInvalidProperty, "top-level 'dns' invalid when specifying subnets"
          end

          if network_spec.has_key?('cloud_properties')
            raise NetworkInvalidProperty, "top-level 'cloud_properties' invalid when specifying subnets"
          end

          subnets = network_spec['subnets'].map do |subnet_properties|
            dns = dns_servers(subnet_properties["name"], subnet_properties)
            cloud_properties =
              safe_property(subnet_properties, "cloud_properties", class: Hash, default: {})
            DynamicNetworkSubnet.new(dns, cloud_properties)
          end
        else
          cloud_properties = safe_property(network_spec, "cloud_properties", class: Hash, default: {})
          dns = dns_servers(network_spec["name"], network_spec)
          subnets = [DynamicNetworkSubnet.new(dns, cloud_properties)]
        end

        name = safe_property(network_spec, "name", :class => String)
        canonical_name = canonical(name)
        logger = TaggedLogger.new(logger, 'network-configuration')

        new(name, canonical_name, subnets, logger)
      end

      def initialize(name, canonical_name, subnets, logger)
        @name = name
        @canonical_name = canonical_name
        @subnets = subnets
        @logger = logger
      end

      attr_reader :subnets

      ##
      # Reserves a network resource.
      #
      # This is either an already used reservation being verified or a new one
      # waiting to be fulfilled.
      # @param [NetworkReservation] reservation
      # @return [Boolean] true if the reservation was fulfilled
      def reserve(reservation)
        @logger.debug("Reserving IP for dynamic network '#{@name}'")

        reservation.mark_reserved_as(DynamicNetworkReservation)
      end

      ##
      # Releases a previous reservation that had been fulfilled.
      # @param [NetworkReservation] reservation
      # @return [void]
      def release(reservation)
        @logger.debug("Releasing IP for dynamic network '#{@name}'")

        reservation.validate_type(DynamicNetworkReservation)
      end

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = VALID_DEFAULTS)
        reservation.validate_type(DynamicNetworkReservation)

        subnet = subnets.first # TODO: care about AZ someday

        config = {
          "type" => "dynamic",
          "cloud_properties" => subnet.cloud_properties
        }
        config["dns"] = subnet.dns if subnet.dns

        if default_properties
          config["default"] = default_properties.sort
        end

        config
      end

      def validate_subnet_azs_contained_in!(availability_zones)
        # nothing to validate
      end

      def validate_has_job!(az_names, job_name)
        # nothing to validate
      end
    end
  end
end
