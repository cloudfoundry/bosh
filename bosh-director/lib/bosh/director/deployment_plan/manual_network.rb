# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module DeploymentPlan
    ##
    # Represents a explicitly configured network.
    class ManualNetwork < Network
      include IpUtil
      include DnsHelper
      include ValidationHelper

      attr_reader :subnets

      ##
      # Creates a new network.
      #
      # @param [Hash] network_spec parsed deployment manifest network section
      # @param [DeploymentPlan::GlobalNetworkResolver] global_network_resolver
      # @param [DeploymentPlan::IpProviderFactory] ip_provider_factory
      # @param [Logger] logger
      def initialize(network_spec, global_network_resolver, ip_provider_factory, logger)
        super(network_spec, logger)

        reserved_ranges = global_network_resolver.reserved_legacy_ranges(@name)
        subnet_specs = safe_property(network_spec, "subnets", :class => Array)

        @subnets = []
        subnet_specs.each do |subnet_spec|
          new_subnet = NetworkSubnet.new(self, subnet_spec, reserved_ranges, ip_provider_factory)
          @subnets.each do |subnet|
            if subnet.overlaps?(new_subnet)
              raise NetworkOverlappingSubnets, "Network `#{name}' has overlapping subnets"
            end
          end
          @subnets << new_subnet
        end

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
        if reservation.ip
          cidr_ip = format_ip(reservation.ip)
          @logger.debug("Reserving static ip '#{cidr_ip}' for manual network '#{@name}'")
          find_subnet(reservation.ip) do |subnet|
            type = subnet.reserve_ip(reservation.instance, reservation.ip)

            reservation.validate_type(type)

            reservation.type = type
            reservation.reserved = true
          end
        else
          unless reservation.dynamic?
            @logger.error("Failed to reserve IP for manual network '#{@name}': IP was not provided for static reservation")
            raise NetworkReservationInvalidType,
                  "New reservations without IPs must be dynamic"
          end

          @logger.debug("Reserving dynamic ip for manual network '#{@name}'")
          @subnets.each do |subnet|
            reservation.ip = subnet.allocate_dynamic_ip(reservation.instance)
            if reservation.ip
              @logger.debug("Reserving IP '#{format_ip(reservation.ip)}' for manual network '#{@name}'")
              reservation.reserved = true
              break
            end
          end

          unless reservation.reserved?
            raise NetworkReservationNotEnoughCapacity,
              "Failed to reserve IP for manual network '#{@name}': no more available"
          end
        end
        reservation.reserved?
      end

      ##
      # Releases a previous reservation that had been fulfilled.
      # @param [NetworkReservation] reservation
      # @return [void]
      def release(reservation)
        unless reservation.ip
          @logger.error("Failed to release IP for manual network '#{@name}': IP must be provided")
          raise NetworkReservationIpMissing,
                "Can't release reservation without an IP"
        end

        @logger.error("Releasing IP '#{format_ip(reservation.ip)}' for manual network #{@name}")
        find_subnet(reservation.ip) do |subnet|
          subnet.release_ip(reservation.ip)
        end
      end

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = VALID_DEFAULTS)
        unless reservation.ip
          raise NetworkReservationIpMissing,
                "Can't generate network settings without an IP"
        end

        config = nil
        find_subnet(reservation.ip) do |subnet|
          ip = ip_to_netaddr(reservation.ip)
          config = {
              "ip" => ip.ip,
              "netmask" => subnet.netmask,
              "cloud_properties" => subnet.cloud_properties
          }

          if default_properties
            config["default"] = default_properties.sort
          end

          config["dns"] = subnet.dns if subnet.dns
          config["gateway"] = subnet.gateway.ip if subnet.gateway
        end
        config
      end

      ##
      # @param [Integer, NetAddr::CIDR, String] ip
      # @yield the subnet that contains the IP.
      def find_subnet(ip)
        @subnets.each do |subnet|
          if subnet.range.contains?(ip)
            yield subnet
            break
          end
        end
      end

      def validate!(availability_zones)
        @subnets.each { |subnet| subnet.validate!(availability_zones) }
      end
    end
  end
end
