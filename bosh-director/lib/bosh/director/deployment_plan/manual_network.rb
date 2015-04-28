# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module DeploymentPlan
    ##
    # Represents a explicitly configured network.
    class ManualNetwork < Network
      include IpUtil
      include DnsHelper
      include ValidationHelper

      ##
      # Creates a new network.
      #
      # @param [DeploymentPlan] deployment associated deployment plan
      # @param [Hash] network_spec parsed deployment manifest network section
      def initialize(deployment, network_spec)
        super

        @subnets = []
        subnets = safe_property(network_spec, "subnets", :class => Array)

        subnets.each do |subnet_spec|
          new_subnet = NetworkSubnet.new(self, subnet_spec)
          @subnets.each do |subnet|
            if subnet.overlaps?(new_subnet)
              raise NetworkOverlappingSubnets,
                    "Network `#{name}' has overlapping subnets"
            end
          end
          @subnets << new_subnet
        end

        # Uncomment line below when integration tests is fixed
        # raise "Must specify at least one subnet" if @subnets.empty?
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
          find_subnet(reservation.ip) do |subnet|
            type = subnet.reserve_ip(reservation.ip)
            if type.nil?
              reservation.error = NetworkReservation::USED
            elsif reservation.type && reservation.type != type
              reservation.error = NetworkReservation::WRONG_TYPE
            else
              reservation.type = type
              reservation.reserved = true
            end
          end
        else
          unless reservation.dynamic?
            raise NetworkReservationInvalidType,
                  "New reservations without IPs must be dynamic"
          end
          @subnets.each do |subnet|
            reservation.ip = subnet.allocate_dynamic_ip
            if reservation.ip
              reservation.reserved = true
              break
            end
          end
          unless reservation.reserved?
            reservation.error = NetworkReservation::CAPACITY
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
          raise NetworkReservationIpMissing,
                "Can't release reservation without an IP"
        end

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
    end
  end
end
