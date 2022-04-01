require 'netaddr'

module Bosh::Director
  module DeploymentPlan
    class ManualNetworkSubnet < Subnet
      extend ValidationHelper
      extend IpUtil
      include IpUtil

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
          range_wrapper = CIDR.new(range_property)
          range = range_wrapper.netaddr

          if range.len <= 1
            raise NetworkInvalidRange, "Invalid network range '#{range_property}', " \
              'should include at least 2 IPs'
          end

          netmask = range_wrapper.netmask
          network_id = range.network
          broadcast = range.nth(range.len - 1)

          if gateway_property
            begin
              gateway = CIDRIP.parse(gateway_property)
            rescue NetAddr::ValidationError
              invalid_gateway(network_name, 'not a valid IP format')
            end

            invalid_gateway(network_name, 'must be inside the range') unless range.contains(gateway)
            invalid_gateway(network_name, "can't be the network id") if gateway.addr == network_id.addr
            invalid_gateway(network_name, "can't be the broadcast IP") if gateway.addr == broadcast.addr
          end

          static_property = safe_property(subnet_spec, 'static', optional: true)

          restricted_ips.add(gateway.addr) if gateway
          restricted_ips.add(network_id.addr)
          restricted_ips.add(broadcast.addr)

          each_ip(reserved_property) do |ip_int|
            ip = CIDRIP.parse(ip_int)
            unless range.contains(ip)
              raise NetworkReservedIpOutOfRange, "Reserved IP '#{ip.to_s}' is out of " \
                "network '#{network_name}' range"
            end

            restricted_ips.add(ip_int)
          end

          Config.director_ips&.each do |cidr|
            each_ip(cidr) do |ip|
              restricted_ips.add(ip)
            end
          end

          each_ip(static_property) do |ip|
            if restricted_ips.include?(ip)
              raise NetworkStaticIpOutOfRange, "Static IP '#{format_ip(ip)}' is in network '#{network_name}' reserved range"
            end

            unless range.contains(CIDRIP.parse(ip))
              raise NetworkStaticIpOutOfRange, "Static IP '#{format_ip(ip)}' is out of network '#{network_name}' range"
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
        return false unless range.version == subnet.range.version

        ! range.rel(subnet.range).nil?
      rescue NetAddr::ValidationError
        false
      end

      def is_reservable?(ip)
        ip = CIDRIP.parse(ip) # TODO NETADDR: according to test should not be neccessary, ip should already be a IPv4 object, however method is sometimes used differently
        return false unless ip.version == range.version

        range.contains(ip) && !restricted_ips.include?(ip.addr)
      rescue NetAddr::ValidationError
        false
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
