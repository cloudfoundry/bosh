# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class NetworkSubnetSpec
      include IpUtil
      include ValidationHelper

      # TODO: could these be downgraded to attr_reader?
      attr_accessor :network
      attr_accessor :range
      attr_accessor :gateway
      attr_accessor :dns
      attr_accessor :cloud_properties
      attr_accessor :netmask

      # @param [NetworkSpec] network Network spec
      # @param [Hash] subnet_spec Raw subnet spec from deployment manifest
      def initialize(network, subnet_spec)
        @network = network

        range_property = safe_property(subnet_spec, "range", :class => String)
        @range = NetAddr::CIDR.create(range_property)

        if @range.size <= 1
          raise NetworkSpecInvalidRange,
                "Invalid network range `#{range_property}', " +
                "should include at least 2 IPs"
        end

        @netmask = @range.wildcard_mask
        network_id = @range.network(:Objectify => true)
        broadcast = @range.broadcast(:Objectify => true)

        gateway_property = safe_property(subnet_spec, "gateway",
                                         :class => String, :optional => true)
        if gateway_property
          @gateway = NetAddr::CIDR.create(gateway_property)
          unless @gateway.size == 1
            invalid_gateway("must be a single IP")
          end
          unless @range.contains?(@gateway)
            invalid_gateway("must be inside the range")
          end
          if @gateway == network_id
            invalid_gateway("can't be the network id")
          end
          if @gateway == broadcast
            invalid_gateway("can't be the broadcast IP")
          end
        end

        dns_property = safe_property(subnet_spec, "dns",
                                     :class => Array, :optional => true)
        if dns_property
          @dns = []
          dns_property.each do |dns|
            dns = NetAddr::CIDR.create(dns)
            unless dns.size == 1
              invalid_dns("must be a single IP")
            end

            @dns << dns.ip
          end
        end

        @cloud_properties = safe_property(subnet_spec, "cloud_properties",
                                          :class => Hash)

        @available_dynamic_ips = Set.new
        @available_static_ips = Set.new

        first_ip = @range.first(:Objectify => true)
        last_ip = @range.last(:Objectify => true)

        (first_ip.to_i .. last_ip.to_i).each do |ip|
          @available_dynamic_ips << ip
        end

        @available_dynamic_ips.delete(@gateway.to_i) if @gateway
        @available_dynamic_ips.delete(network_id.to_i)
        @available_dynamic_ips.delete(broadcast.to_i)

        reserved_ips = safe_property(subnet_spec, "reserved", :optional => true)
        static_ips = safe_property(subnet_spec, "static", :optional => true)

        each_ip(reserved_ips) do |ip|
          unless @available_dynamic_ips.delete?(ip)
            raise NetworkSpecReservedIpOutOfRange,
                  "Reserved IP `#{format_ip(ip)}' is out of " +
                  "network `#{@network.name}' range"
          end
        end

        each_ip(static_ips) do |ip|
          unless @available_dynamic_ips.delete?(ip)
            raise NetworkSpecStaticIpOutOfRange,
                  "Static IP `#{format_ip(ip)}' is out of " +
                  "network `#{@network.name}' range"
          end
          @available_static_ips.add(ip)
        end

        # Keeping track of initial pools to understand
        # where to release no longer needed IPs
        @dynamic_ip_pool = @available_dynamic_ips.dup
        @static_ip_pool = @available_static_ips.dup
      end

      def overlaps?(subnet)
        @range == subnet.range ||
          @range.contains?(subnet.range) ||
          subnet.range.contains?(@range)
      end

      def reserve_ip(ip)
        ip = ip.to_i
        if @available_static_ips.delete?(ip)
          :static
        elsif @available_dynamic_ips.delete?(ip)
          :dynamic
        else
          nil
        end
      end

      def release_ip(ip)
        ip = ip.to_i
        if @dynamic_ip_pool.include?(ip)
          @available_dynamic_ips.add(ip)
        elsif @static_ip_pool.include?(ip)
          @available_static_ips.add(ip)
        else
          raise NetworkReservationIpNotOwned,
                "Can't release IP `#{format_ip(ip)}' " +
                "back to `#{@network.name}' network: " +
                "it's' neither in dynamic nor in static pool"
        end
      end

      def allocate_dynamic_ip
        ip = @available_dynamic_ips.first
        if ip
          @available_dynamic_ips.delete(ip)
        end
        ip
      end

      def dynamic_ips_count
        @available_dynamic_ips.size
      end

      def static_ips_count
        @available_static_ips.size
      end

      private

      # @param [String] reason
      # @raise NetworkSpecInvalidGateway
      def invalid_gateway(reason)
        raise NetworkSpecInvalidGateway,
              "Invalid gateway for network `#{@network.name}': #{reason}"
      end

      # @param [String] reason
      # @raise NetworkSpecInvalidDns
      def invalid_dns(reason)
        raise NetworkSpecInvalidDns,
              "Invalid DNS for network `#{@network.name}': #{reason}"
      end
    end
  end
end