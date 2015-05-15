module Bosh::Director
  module DeploymentPlan
    class NetworkSubnet
      include DnsHelper
      include ValidationHelper
      include IpUtil

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
      def initialize(network, subnet_spec, ip_provider_klazz)
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

        reserved_property = safe_property(subnet_spec, "reserved", :optional => true)
        static_property = safe_property(subnet_spec, "static", :optional => true)

        restricted_ips = Set.new
        restricted_ips.add(@gateway.to_i) if @gateway
        restricted_ips.add(network_id.to_i)
        restricted_ips.add(broadcast.to_i)

        each_ip(reserved_property) do |ip|
          unless @range.contains?(ip)
            raise NetworkReservedIpOutOfRange,
              "Reserved IP `#{format_ip(ip)}' is out of " +
                "network `#{@network.name}' range"
          end
          restricted_ips.add(ip)
        end

        static_ips = Set.new
        each_ip(static_property) do |ip|
          unless @range.contains?(ip) && !restricted_ips.include?(ip)
            raise NetworkStaticIpOutOfRange,
              "Static IP `#{format_ip(ip)}' is out of " +
                "network `#{@network.name}' range"
          end
          static_ips.add(ip)
        end

        @ip_provider = ip_provider_klazz.new(@range, @network.name, restricted_ips, static_ips)
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
  end
end
