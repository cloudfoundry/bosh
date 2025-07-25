module Bosh::Director
  module DeploymentPlan
    class DynamicNetwork < NetworkWithSubnets
      include Bosh::Director::IpUtil
      extend ValidationHelper

      def self.parse(network_spec, availability_zones, logger)
        name = safe_property(network_spec, 'name', :class => String)
        Canonicalizer.canonicalize(name)
        logger = TaggedLogger.new(logger, 'network-configuration')
        name_server_parser = NetworkParser::NameServersParser.new

        validate_network_has_no_key('az', name, network_spec)
        validate_network_has_no_key('azs', name, network_spec)
        validate_network_has_no_key('managed', name, network_spec)
        validate_network_has_no_key('prefix', name, network_spec)

        if network_spec.has_key?('subnets')
          validate_network_has_no_key_while_subnets_present('dns', name, network_spec)
          validate_network_has_no_key_while_subnets_present('cloud_properties', name, network_spec)

          subnets = network_spec['subnets'].map do |subnet_properties|
            name_servers = name_server_parser.parse(subnet_properties['name'], subnet_properties)
            cloud_properties = safe_property(subnet_properties, 'cloud_properties', class: Hash, default: {})
            prefix = safe_property(subnet_properties, 'prefix', class: Integer, default: IPV4_DEFAULT_PREFIX_SIZE)
            raise NetworkInvalidProperty, "Prefix property is not supported for dynamic networks." unless prefix == IPV4_DEFAULT_PREFIX_SIZE
            subnet_availability_zones = parse_availability_zones(subnet_properties, availability_zones, name)
            DynamicNetworkSubnet.new(name_servers, cloud_properties, subnet_availability_zones, prefix)
          end
        else
          cloud_properties = safe_property(network_spec, 'cloud_properties', class: Hash, default: {})
          prefix = IPV4_DEFAULT_PREFIX_SIZE # we need to set the ipv4 default value (dynamic networks only support ipv4)

          name_servers = name_server_parser.parse(network_spec['name'], network_spec)
          subnets = [DynamicNetworkSubnet.new(name_servers, cloud_properties, nil, prefix)]
        end

        new(name, subnets, logger, prefix)
      end

      def self.validate_network_has_no_key_while_subnets_present(key, name, network_spec)
        if network_spec.has_key?(key)
          raise NetworkInvalidProperty, "Network '#{name}' must not specify '#{key}' when also specifying 'subnets'. " +
              "Instead, '#{key}' should be specified on subnet entries."
        end
      end

      def self.validate_network_has_no_key(key, name, network_spec)
        if network_spec.has_key?(key)
          raise NetworkInvalidProperty, "Network '#{name}' must not specify '#{key}'."
        end
      end

      def self.parse_availability_zones(spec, availability_zones, name)

        has_availability_zones_key = spec.has_key?('azs')
        has_availability_zone_key = spec.has_key?('az')

        if has_availability_zone_key && has_availability_zones_key
          raise Bosh::Director::NetworkInvalidProperty, "Network '#{name}' contains both 'az' and 'azs'. Choose one."
        end

        if has_availability_zones_key
          subnet_availability_zones = safe_property(spec, 'azs', class: Array, optional: true)
          if subnet_availability_zones.empty?
            raise Bosh::Director::NetworkInvalidProperty, "Network '#{name}' refers to an empty 'azs' array"
          end
          subnet_availability_zones.each do |zone|
            check_validity_of_availability_zone(zone, availability_zones, name)
          end
          subnet_availability_zones
        else
          availability_zone = safe_property(spec, 'az', class: String, optional: true)
          check_validity_of_availability_zone(availability_zone, availability_zones, name)
          availability_zone.nil? ? nil : [availability_zone]
        end
      end

      def self.check_validity_of_availability_zone(availability_zone, availability_zones, name)
        unless availability_zone.nil? || availability_zones.any? { |az| az.name == availability_zone }
          raise Bosh::Director::NetworkSubnetUnknownAvailabilityZone, "Network '#{name}' refers to an unknown availability zone '#{availability_zone}'"
        end
      end

      def initialize(name, subnets, prefix, logger)
        super(name, logger)
        @subnets = subnets
        @prefix = prefix
      end

      attr_reader :subnets

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @param [AvailabilityZone] availability zone
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = Network::REQUIRED_DEFAULTS, availability_zone = nil)
        unless reservation.dynamic?
          raise NetworkReservationWrongType,
            "IP '#{reservation.ip}' on network '#{reservation.network.name}' does not belong to dynamic pool"
        end

        if availability_zone.nil?
          subnet = subnets.first
        else
          subnet = find_subnet_for_az(availability_zone.name)
          unless subnet
            raise NetworkSubnetInvalidAvailabilityZone,
              "Network '#{name}' has no matching subnet for availability zone '#{availability_zone.name}'"
          end
        end

        config = {
          "type" => "dynamic",
          "cloud_properties" => subnet.cloud_properties
        }
        config["dns"] = subnet.dns if subnet.dns

        if default_properties
          config["default"] = default_properties.sort
        end

        config
      end

      def validate_reference_from_job!(job_network_spec, job_name)
        if job_network_spec.has_key?('static_ips')
          raise JobStaticIPNotSupportedOnDynamicNetwork,
            "Instance group '#{job_name}' using dynamic network '#{name}' cannot specify static IP(s)"
        end
      end

      def find_az_names_for_ip(ip)
        # On dynamic network ip does not belong to any subnet
        availability_zones
      end

      private

      def find_subnet_for_az(az_name)
        @subnets.find { |subnet| subnet.availability_zone_names.include?(az_name) }
      end
    end
  end
end
