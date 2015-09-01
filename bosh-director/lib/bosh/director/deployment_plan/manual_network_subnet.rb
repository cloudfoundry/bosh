module Bosh::Director
  module DeploymentPlan
    class ManualNetworkSubnet
      include DnsHelper
      include ValidationHelper
      include IpUtil

      attr_reader :network, :range, :gateway, :dns, :cloud_properties,
        :netmask, :availability_zone

      def initialize(network, subnet_spec, availability_zones, legacy_reserved_ranges, ip_provider_factory)
        @network = network

        Config.logger.debug("reserved ranges #{legacy_reserved_ranges.inspect}")
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

        ignore_missing_gateway = Bosh::Director::Config.ignore_missing_gateway
        gateway_property = safe_property(subnet_spec, "gateway", class: String, optional: ignore_missing_gateway)
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

        @availability_zone = parse_availability_zone(subnet_spec, network, availability_zones)

        @cloud_properties = safe_property(subnet_spec, "cloud_properties", class: Hash, default: {})

        reserved_property = safe_property(subnet_spec, "reserved", :optional => true)
        static_property = safe_property(subnet_spec, "static", :optional => true)

        @restricted_ips = Set.new
        @restricted_ips.add(@gateway.to_i) if @gateway
        @restricted_ips.add(network_id.to_i)
        @restricted_ips.add(broadcast.to_i)

        each_ip(reserved_property) do |ip|
          unless @range.contains?(ip)
            raise NetworkReservedIpOutOfRange,
              "Reserved IP `#{format_ip(ip)}' is out of " +
                "network `#{@network.name}' range"
          end
          @restricted_ips.add(ip)
        end

        @static_ips = Set.new
        each_ip(static_property) do |ip|
          unless @range.contains?(ip) && !@restricted_ips.include?(ip)
            raise NetworkStaticIpOutOfRange,
              "Static IP `#{format_ip(ip)}' is out of " +
                "network `#{@network.name}' range"
          end
          @static_ips.add(ip)
        end

        legacy_reserved_ranges.each do |cidr_range|
          cidr_range.range(0, nil, Objectify: true).each do |ip|
            @restricted_ips.add(ip.to_i) unless @static_ips.include?(ip.to_i)
          end
        end

        @ip_provider = ip_provider_factory.create(@range, @network.name, @restricted_ips, @static_ips)
      end

      def reserve_ip(reservation)
        @ip_provider.reserve_ip(reservation)
      end

      def release_ip(ip)
        @ip_provider.release_ip(ip)
      end

      def allocate_dynamic_ip(instance)
        @ip_provider.allocate_dynamic_ip(instance)
      end

      def overlaps?(subnet)
        @range == subnet.range ||
          @range.contains?(subnet.range) ||
          subnet.range.contains?(@range)
      end

      def restricted_ips
        @restricted_ips
      end

      def static_ips
        @static_ips
      end

      private

      def parse_availability_zone(subnet_spec, network, availability_zones)
        availability_zone = safe_property(subnet_spec, "availability_zone", class: String, optional: true)
        unless availability_zone.nil? || availability_zones.any? { |az| az.name == availability_zone }
          raise Bosh::Director::NetworkSubnetUnknownAvailabilityZone, "Network '#{network.name}' refers to an unknown availability zone '#{availability_zone}'"
        end
        availability_zone
      end

      def invalid_gateway(reason)
        raise NetworkInvalidGateway,
              "Invalid gateway for network `#{@network.name}': #{reason}"
      end
    end
  end
end
