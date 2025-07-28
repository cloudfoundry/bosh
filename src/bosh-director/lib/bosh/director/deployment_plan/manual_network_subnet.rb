module Bosh::Director
  module DeploymentPlan
    class ManualNetworkSubnet < Subnet
      extend ValidationHelper
      extend IpUtil

      attr_reader :network_name, :name, :dns,
                  :availability_zone_names, :netmask_bits, :prefix
      attr_accessor :cloud_properties, :range, :gateway, :restricted_ips,
                    :static_ips, :netmask

      def self.parse(network_name, subnet_spec, availability_zones, managed = false)
        @logger = Config.logger

        sn_name = safe_property(subnet_spec, 'name', optional: !managed)
        range_property = safe_property(subnet_spec, 'range', class: String, optional: managed)
        ignore_missing_gateway = Bosh::Director::Config.ignore_missing_gateway
        gateway_property = safe_property(subnet_spec, 'gateway', class: String, optional: ignore_missing_gateway || managed)
        reserved_property = safe_property(subnet_spec, 'reserved', optional: true)
        prefix = safe_property(subnet_spec, 'prefix', optional: true)
        restricted_ips = Set.new
        static_ips = Set.new
        static_cidrs = Set.new

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
          broadcast = range.last

          if gateway_property
            gateway = Bosh::Director::IpAddrOrCidr.new(gateway_property)
            invalid_gateway(network_name, 'must be a single IP') unless gateway.count == 1
            invalid_gateway(network_name, 'must be inside the range') unless range.include?(gateway)
            invalid_gateway(network_name, "can't be the network id") if gateway == range
            invalid_gateway(network_name, "can't be the broadcast IP") if gateway == broadcast
          end

          static_property = safe_property(subnet_spec, 'static', optional: true)

          restricted_ips.add(gateway) if gateway
          restricted_ips.add(range.first)
          restricted_ips.add(broadcast)

          each_ip(reserved_property, false) do |ip|
            unless range.include?(ip)
              raise NetworkReservedIpOutOfRange, "Reserved IP '#{to_ipaddr(ip)}' is out of " \
                "network '#{network_name}' range"
            end

            restricted_ips.add(ip)
          end

          Config.director_ips&.each do |cidr|
            each_ip(cidr) do |ip|
              restricted_ips.add(ip)
            end
          end

          restricted_ips.reject! do |ip|
            restricted_ips.any? do |other_ip| 
              includes = other_ip.include?(ip) rescue false
              includes && other_ip.prefix < ip.prefix
            end
          end

          each_ip(static_property, false) do |ip|
            if ip_in_array?(ip, restricted_ips)
              raise NetworkStaticIpOutOfRange, "Static IP '#{to_ipaddr(ip)}' is in network '#{network_name}' reserved range"
            end

            unless range.include?(ip)
              raise NetworkStaticIpOutOfRange, "Static IP '#{to_ipaddr(ip)}' is out of network '#{network_name}' range"
            end

            static_cidrs.add(ip)
          end

          if prefix.nil?
            if range.ipv6?
              prefix = Network::IPV6_DEFAULT_PREFIX_SIZE
            else
              prefix = Network::IPV4_DEFAULT_PREFIX_SIZE
            end
          else
            if range.prefix > prefix.to_i
              raise NetworkPrefixSizeTooBig, "Prefix size '#{prefix}' is larger than range prefix '#{range.prefix}'"
            end
          end

          if prefix == Network::IPV6_DEFAULT_PREFIX_SIZE || prefix == Network::IPV4_DEFAULT_PREFIX_SIZE
            static_ips = static_cidrs
          else
            static_cidrs.each do |static_cidr|
              static_cidr.each_base_address(prefix) do |base_address_int|
                if static_cidr.include?(base_address_int)
                  static_ips.add(Bosh::Director::IpAddrOrCidr.new(base_address_int))
                end
                break if static_cidr.last.to_i <= base_address_int
              end
            end
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
          prefix
        )
      end

      def initialize(network_name, range, gateway, name_servers, cloud_properties, netmask, availability_zone_names, restricted_ips, static_ips, subnet_name = nil, netmask_bits = nil, prefix = nil)
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
        @prefix = prefix.to_s
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
        restricted_ips.each do | restricted_ip |
          return false if restricted_ip.include?(ip)
          rescue IPAddr::InvalidAddressError  # when ip versions are not the same
          return false
        end

        range.include?(ip.to_range.first) && range.include?(ip.to_range.last)
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
