module Bosh::Director
  module DeploymentPlan
    class DynamicNetwork < NetworkWithSubnets
      include Bosh::Director::IpUtil
      extend ValidationHelper

      def self.parse(network_spec, availability_zones, logger)
        name = safe_property(network_spec, 'name', :class => String)
        Canonicalizer.canonicalize(name)
        logger = TaggedLogger.new(logger, 'network-configuration')
        dns_manager = DnsManager.create

        if network_spec.has_key?('subnets')
          if network_spec.has_key?('dns')
            raise NetworkInvalidProperty, "top-level 'dns' invalid when specifying subnets"
          end

          if network_spec.has_key?('az')
            raise NetworkInvalidProperty, "top-level 'az' invalid when specifying subnets"
          end

          if network_spec.has_key?('cloud_properties')
            raise NetworkInvalidProperty, "top-level 'cloud_properties' invalid when specifying subnets"
          end

          subnets = network_spec['subnets'].map do |subnet_properties|
            dns_spec = safe_property(subnet_properties, 'dns', :class => Array, :optional => true)
            dns = dns_manager.dns_servers(subnet_properties['name'], dns_spec)
            cloud_properties = safe_property(subnet_properties, 'cloud_properties', class: Hash, default: {})
            subnet_availability_zones = parse_availability_zones(subnet_properties, availability_zones, name)
            DynamicNetworkSubnet.new(dns, cloud_properties, subnet_availability_zones)
          end
        else
          cloud_properties = safe_property(network_spec, 'cloud_properties', class: Hash, default: {})
          dns_spec = safe_property(network_spec, 'dns', :class => Array, :optional => true)
          dns = dns_manager.dns_servers(network_spec['name'], dns_spec)
          network_availability_zones = parse_availability_zones(network_spec, availability_zones, name)
          subnets = [DynamicNetworkSubnet.new(dns, cloud_properties, network_availability_zones)]
        end

        new(name, subnets, logger)
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

      def initialize(name, subnets, logger)
        super(name, logger)
        @subnets = subnets
      end

      attr_reader :subnets

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @param [AvailabilityZone] availability zone
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = Network::VALID_DEFAULTS, availability_zone = nil)
        unless reservation.dynamic?
          raise NetworkReservationWrongType,
            "IP '#{format_ip(reservation.ip)}' on network '#{reservation.network.name}' does not belong to dynamic pool"
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

      def validate_reference_from_job!(job_network_spec)
        if job_network_spec.has_key?('static_ips')
          raise JobStaticIPNotSupportedOnDynamicNetwork,
            "Job using dynamic network '#{name}' cannot specify static IP(s)"
        end
      end

      private

      def find_subnet_for_az(az_name)
        @subnets.find { |subnet| subnet.availability_zone_names.include?(az_name) }
      end
    end
  end
end
