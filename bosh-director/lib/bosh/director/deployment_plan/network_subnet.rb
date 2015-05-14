module Bosh::Director
  module DeploymentPlan
    class NetworkSubnet
      include DnsHelper
      include ValidationHelper

      # @return [DeploymentPlan::Network] Network this subnet belongs to
      attr_reader :network

      # @return [NetAddr::CIDR] Subnet range
      attr_reader :range

      # @return [NetAddr::CIDR] Subnet gateway IP address
      attr_reader :gateway

      # @return [Array<String>] Subnet DNS IP addresses
      attr_reader :dns

      # @return [Hash] Subnet cloud properties (VLAN etc.)
      attr_reader :cloud_properties

      # @return [String] Subnet netmask
      attr_reader :netmask

      # @param [DeploymentPlan::Network] network Network
      # @param [Hash] subnet_spec Raw subnet spec from deployment manifest
      def initialize(network, subnet_spec)
        @network = network

        range_property = safe_property(subnet_spec, "range", :class => String)
        @range = NetAddr::CIDR.create(range_property)

        if @range.size <= 1
          raise NetworkInvalidRange,
                "Invalid network range `#{range_property}', " +
                "should include at least 2 IPs"
        end

        @netmask = @range.wildcard_mask
        network_id = @range.network(:Objectify => true)
        broadcast = @range.broadcast(:Objectify => true)

        gateway_property = safe_property(subnet_spec, "gateway", class: String)
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

        @dns = dns_servers(@network.name, subnet_spec)

        @cloud_properties = safe_property(subnet_spec, "cloud_properties", class: Hash, default: {})

        reserved_ips = safe_property(subnet_spec, "reserved", :optional => true)
        static_ips = safe_property(subnet_spec, "static", :optional => true)

        @ip_provider = InMemoryIpProvider.new(@range, @gateway, network_id, broadcast, static_ips, reserved_ips, @network.name)
      end

      def overlaps?(subnet)
        @range == subnet.range ||
          @range.contains?(subnet.range) ||
          subnet.range.contains?(@range)
      end

      def reserve_ip(ip)
        @ip_provider.reserve_ip(ip)
      end

      def release_ip(ip)
        @ip_provider.release_ip(ip)
      end

      def allocate_dynamic_ip
        @ip_provider.allocate_dynamic_ip
      end

      private

      # @param [String] reason
      # @raise NetworkInvalidGateway
      def invalid_gateway(reason)
        raise NetworkInvalidGateway,
              "Invalid gateway for network `#{@network.name}': #{reason}"
      end
    end

    class InMemoryIpProvider
      include IpUtil

      def initialize(range, gateway, network_id, broadcast, static_ips, reserved_ips, network_name)
        @range = range
        @gateway = gateway
        @network_name = network_name
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

        each_ip(reserved_ips) do |ip|
          unless @available_dynamic_ips.delete?(ip)
            raise NetworkReservedIpOutOfRange,
              "Reserved IP `#{format_ip(ip)}' is out of " +
                "network `#{@network_name}' range"
          end
        end

        each_ip(static_ips) do |ip|
          unless @available_dynamic_ips.delete?(ip)
            raise NetworkStaticIpOutOfRange,
              "Static IP `#{format_ip(ip)}' is out of " +
                "network `#{@network_name}' range"
          end
          @available_static_ips.add(ip)
        end

        # Keeping track of initial pools to understand
        # where to release no longer needed IPs
        @dynamic_ip_pool = @available_dynamic_ips.dup
        @static_ip_pool = @available_static_ips.dup
      end

      def allocate_dynamic_ip
        ip = @available_dynamic_ips.first
        if ip
          @available_dynamic_ips.delete(ip)
        end
        ip
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
              "back to `#{@network_name}' network: " +
              "it's' neither in dynamic nor in static pool"
        end
      end
    end
  end
end
