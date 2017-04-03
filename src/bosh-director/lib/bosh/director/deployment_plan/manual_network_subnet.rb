module Bosh::Director
  module DeploymentPlan
    class ManualNetworkSubnet
      extend ValidationHelper
      extend IpUtil

      attr_reader :network_name, :range, :gateway, :dns, :cloud_properties,
        :netmask, :availability_zone_names, :restricted_ips, :static_ips

      def self.parse(network_name, subnet_spec, availability_zones, legacy_reserved_ranges)
        @logger = Config.logger

        @logger.debug("reserved ranges #{legacy_reserved_ranges.map {|r| r.first == r.last ? "#{r.first}" : "#{r.first}-#{r.last}"}.join(', ')}")
        range_property = safe_property(subnet_spec, "range", :class => String)
        range = NetAddr::CIDR.create(range_property)

        if range.size <= 1
          raise NetworkInvalidRange,
            "Invalid network range '#{range_property}', " +
              "should include at least 2 IPs"
        end

        netmask = range.wildcard_mask
        network_id = range.network(:Objectify => true)
        broadcast = range.broadcast(:Objectify => true)

        ignore_missing_gateway = Bosh::Director::Config.ignore_missing_gateway
        gateway_property = safe_property(subnet_spec, "gateway", class: String, optional: ignore_missing_gateway)
        if gateway_property
          gateway = NetAddr::CIDR.create(gateway_property)
          unless gateway.size == 1
            invalid_gateway(network_name, "must be a single IP")
          end
          unless range.contains?(gateway)
            invalid_gateway(network_name, "must be inside the range")
          end
          if gateway == network_id
            invalid_gateway(network_name, "can't be the network id")
          end
          if gateway == broadcast
            invalid_gateway(network_name, "can't be the broadcast IP")
          end
        end

        name_server_parser = NetworkParser::NameServersParser.new
        name_servers = name_server_parser.parse(network_name, subnet_spec)

        availability_zone_names = parse_availability_zones(subnet_spec, network_name, availability_zones)

        cloud_properties = safe_property(subnet_spec, "cloud_properties", class: Hash, default: {})

        reserved_property = safe_property(subnet_spec, "reserved", :optional => true)
        static_property = safe_property(subnet_spec, "static", :optional => true)

        restricted_ips = Set.new
        restricted_ips.add(gateway.to_i) if gateway
        restricted_ips.add(network_id.to_i)
        restricted_ips.add(broadcast.to_i)

        each_ip(reserved_property) do |ip|
          unless range.contains?(ip)
            raise NetworkReservedIpOutOfRange,
              "Reserved IP '#{format_ip(ip)}' is out of " +
                "network '#{network_name}' range"
          end
          restricted_ips.add(ip)
        end

        static_ips = Set.new
        each_ip(static_property) do |ip|
          if restricted_ips.include?(ip)
            raise NetworkStaticIpOutOfRange,
              "Static IP '#{format_ip(ip)}' is in network '#{network_name}' reserved range"
          end
          unless range.contains?(ip)
            raise NetworkStaticIpOutOfRange,
              "Static IP '#{format_ip(ip)}' is out of network '#{network_name}' range"
          end
          static_ips.add(ip)
        end

        legacy_reserved_ranges.each do |cidr_range|
          cidr_range.range(0, nil, Objectify: true).each do |ip|
            restricted_ips.add(ip.to_i) unless static_ips.include?(ip.to_i)
          end
        end

        new(network_name, range, gateway, name_servers, cloud_properties, netmask, availability_zone_names, restricted_ips, static_ips)
      end

      def initialize(network_name, range, gateway, name_servers, cloud_properties, netmask, availability_zone_names, restricted_ips, static_ips)
        @network_name = network_name
        @range = range
        @gateway = gateway
        @dns = name_servers
        @cloud_properties = cloud_properties
        @netmask = netmask
        @availability_zone_names = availability_zone_names
        @restricted_ips = restricted_ips
        @static_ips = static_ips
      end

      def overlaps?(subnet)
        range == subnet.range ||
          range.contains?(subnet.range) ||
          subnet.range.contains?(range)
      end

      def is_reservable?(ip)
        range.contains?(ip) && !restricted_ips.include?(ip.to_i)
      end

      private

      def self.parse_availability_zones(subnet_spec, network_name, availability_zones)
        has_availability_zones_key = subnet_spec.has_key?('azs')
        has_availability_zone_key = subnet_spec.has_key?('az')
        if has_availability_zones_key && has_availability_zone_key
          raise Bosh::Director::NetworkInvalidProperty, "Network '#{network_name}' contains both 'az' and 'azs'. Choose one."
        end

        if has_availability_zones_key
          zones = safe_property(subnet_spec, 'azs', class: Array, optional: true)
          if zones.empty?
            raise Bosh::Director::NetworkInvalidProperty, "Network '#{network_name}' refers to an empty 'azs' array"
          end
          zones.each do |zone|
            check_validity_of_subnet_availability_zone(zone, availability_zones, network_name)
          end
          zones
        else
          availability_zone_name = safe_property(subnet_spec, 'az', class: String, optional: true)
          check_validity_of_subnet_availability_zone(availability_zone_name, availability_zones, network_name)
          availability_zone_name.nil? ? nil : [availability_zone_name]
        end
      end

      def self.invalid_gateway(network_name, reason)
        raise NetworkInvalidGateway,
              "Invalid gateway for network '#{network_name}': #{reason}"
      end

      def self.check_validity_of_subnet_availability_zone(availability_zone_name, availability_zones, network_name)
        unless availability_zone_name.nil? || availability_zones.any? { |az| az.name == availability_zone_name }
          raise Bosh::Director::NetworkSubnetUnknownAvailabilityZone, "Network '#{network_name}' refers to an unknown availability zone '#{availability_zone_name}'"
        end
      end
    end
  end
end
