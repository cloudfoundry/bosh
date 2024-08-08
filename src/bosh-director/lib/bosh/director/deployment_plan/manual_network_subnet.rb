module Bosh::Director
  module DeploymentPlan
    class ManualNetworkSubnet < Subnet
      extend ValidationHelper
      extend IpUtil

      attr_reader :network_name, :name, :dns,
                  :availability_zone_names, :netmask_bits
      attr_accessor :cloud_properties, :range, :gateway, :restricted_ips,
                    :static_ips, :netmask

      def self.parse(network_name, subnet_spec, availability_zones, managed = false)
        @logger = Config.logger

        sn_name = safe_property(subnet_spec, 'name', optional: !managed)
        range_property = safe_property(subnet_spec, 'range', class: String, optional: managed)
        ignore_missing_gateway = Bosh::Director::Config.ignore_missing_gateway
        gateway_property = safe_property(subnet_spec, 'gateway', class: String, optional: ignore_missing_gateway || managed)
        reserved_property = safe_property(subnet_spec, 'reserved', optional: true)
        restricted_ips = Set.new
        static_ips = Set.new

        if managed && !range_property
          range_property, gateway_property, reserved_property = parse_properties_from_database(network_name, sn_name)
        end

        if range_property
          range = Bosh::Director::IpAddrOrCidr.new(range_property)

          if range.count <= 1
            raise NetworkInvalidRange, "Invalid network range '#{range_property}', " \
              'should include at least 2 IPs'
          end

          netmask = range.netmask
          broadcast = range.to_range.last

          if gateway_property
            gateway = Bosh::Director::IpAddrOrCidr.new(gateway_property)
            invalid_gateway(network_name, 'must be a single IP') unless gateway.count == 1
            invalid_gateway(network_name, 'must be inside the range') unless range.include?(gateway)
            invalid_gateway(network_name, "can't be the network id") if gateway == range
            invalid_gateway(network_name, "can't be the broadcast IP") if gateway == broadcast
          end

          static_property = safe_property(subnet_spec, 'static', optional: true)

          restricted_ips.add(gateway.to_i) if gateway
          restricted_ips.add(range.to_i)
          restricted_ips.add(broadcast.to_i)

          each_ip(reserved_property) do |ip|
            unless range.include?(ip)
              raise NetworkReservedIpOutOfRange, "Reserved IP '#{format_ip(ip)}' is out of " \
                "network '#{network_name}' range"
            end

            restricted_ips.add(ip)
          end

          Config.director_ips&.each do |cidr|
            each_ip(cidr) do |ip|
              restricted_ips.add(ip)
            end
          end

          each_ip(static_property) do |ip|
            if restricted_ips.include?(ip)
              raise NetworkStaticIpOutOfRange, "Static IP '#{to_ipaddr(ip)}' is in network '#{network_name}' reserved range"
            end

            unless range.include?(ip)
              raise NetworkStaticIpOutOfRange, "Static IP '#{to_ipaddr(ip)}' is out of network '#{network_name}' range"
            end

            static_ips.add(ip)
          end
        end

        name_server_parser = NetworkParser::NameServersParser.new
        name_servers = name_server_parser.parse(network_name, subnet_spec)
        availability_zone_names = parse_availability_zones(subnet_spec, network_name, availability_zones)
        netmask_bits = safe_property(subnet_spec, 'netmask_bits', class: Integer, optional: true)
        cloud_properties = safe_property(subnet_spec, 'cloud_properties', class: Hash, default: {})

        new(
          network_name,
          range,
          gateway,
          name_servers,
          cloud_properties,
          netmask,
          availability_zone_names,
          restricted_ips,
          static_ips,
          sn_name,
          netmask_bits,
        )
      end

      def initialize(network_name, range, gateway, name_servers, cloud_properties, netmask, availability_zone_names, restricted_ips, static_ips, subnet_name = nil, netmask_bits = nil)
        @network_name = network_name
        @name = subnet_name
        @netmask_bits = netmask_bits
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
        return false unless range && subnet.range

        range == subnet.range ||
          range.include?(subnet.range) ||
          subnet.range.include?(range)
      rescue IPAddr::InvalidAddressError
        false
      end

      def is_reservable?(ip)
        range.include?(ip) && !restricted_ips.include?(ip.to_i)
      end

      def self.parse_properties_from_database(network_name, subnet_name)
        nw = Bosh::Director::Models::Network.first(name: network_name)
        return unless nw
        sn = nw.subnets.find { |s| s.name == subnet_name }
        return unless sn
        [sn.range, sn.gateway, JSON.parse(sn.reserved)]
      end

      def self.invalid_gateway(network_name, reason)
        raise NetworkInvalidGateway,
              "Invalid gateway for network '#{network_name}': #{reason}"
      end
    end
  end
end
