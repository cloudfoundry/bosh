# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class NetworkSubnetSpec
      include IpUtil
      include ValidationHelper

      attr_accessor :network
      attr_accessor :range
      attr_accessor :gateway
      attr_accessor :dns
      attr_accessor :cloud_properties
      attr_accessor :netmask

      def initialize(network, subnet_spec)
        @network = network
        @range = NetAddr::CIDR.create(safe_property(subnet_spec, "range", :class => String))
        raise ArgumentError, "invalid range" unless @range.size > 1

        @netmask = @range.wildcard_mask

        gateway_property = safe_property(subnet_spec, "gateway", :class => String, :optional => true)
        if gateway_property
          @gateway = NetAddr::CIDR.create(gateway_property)
          raise ArgumentError, "gateway must be a single ip" unless @gateway.size == 1
          raise ArgumentError, "gateway must be inside the range" unless @range.contains?(@gateway)
        end

        dns_property = safe_property(subnet_spec, "dns", :class => Array, :optional => true)
        if dns_property
          @dns = []
          dns_property.each do |dns|
            dns = NetAddr::CIDR.create(dns)
            raise ArgumentError, "dns entry must be a single ip" unless dns.size == 1
            @dns << dns.ip
          end
        end

        @cloud_properties = safe_property(subnet_spec, "cloud_properties", :class => Hash)

        @available_dynamic_ips = Set.new
        @available_static_ips = Set.new

        first_ip = @range.first(:Objectify => true)
        last_ip = @range.last(:Objectify => true)

        (first_ip.to_i .. last_ip.to_i).each { |ip| @available_dynamic_ips << ip }

        @available_dynamic_ips.delete(@gateway.to_i) if @gateway
        @available_dynamic_ips.delete(@range.network(:Objectify => true).to_i)
        @available_dynamic_ips.delete(@range.broadcast(:Objectify => true).to_i)

        each_ip(safe_property(subnet_spec, "reserved", :optional => true)) do |ip|
          unless @available_dynamic_ips.delete?(ip)
            raise ArgumentError, "reserved IP must be an available (not gateway, etc..) inside the range"
          end
        end

        each_ip(safe_property(subnet_spec, "static", :optional => true)) do |ip|
          unless @available_dynamic_ips.delete?(ip)
            raise ArgumentError, "static IP must be an available (not reserved) inside the range"
          end
          @available_static_ips.add(ip)
        end

        # Keeping track of initial pools to understand
        # where to release no longer needed IPs
        @dynamic_ip_pool = @available_dynamic_ips.dup
        @static_ip_pool = @available_static_ips.dup
      end

      def overlaps?(subnet)
        @range == subnet.range || @range.contains?(subnet.range) || subnet.range.contains?(@range)
      end

      def reserve_ip(ip)
        if @available_static_ips.delete?(ip.to_i)
          :static
        elsif @available_dynamic_ips.delete?(ip.to_i)
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
          raise "Invalid IP to release: neither in dynamic nor in static pool"
        end
      end

      def allocate_dynamic_ip
        ip = @available_dynamic_ips.first
        if ip
          @available_dynamic_ips.delete(ip)
        end
        ip
      end
    end
  end
end