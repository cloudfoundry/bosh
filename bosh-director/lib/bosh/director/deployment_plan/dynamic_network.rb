module Bosh::Director
  module DeploymentPlan
    class DynamicNetwork
      include DnsHelper
      include Bosh::Director::IpUtil
      extend DnsHelper
      extend ValidationHelper

      def self.parse(network_spec, availability_zones, logger)
        name = safe_property(network_spec, 'name', :class => String)
        canonical_name = canonical(name)
        logger = TaggedLogger.new(logger, 'network-configuration')

        if network_spec.has_key?('subnets')
          if network_spec.has_key?('dns')
            raise NetworkInvalidProperty, "top-level 'dns' invalid when specifying subnets"
          end

          if network_spec.has_key?('availability_zone')
            raise NetworkInvalidProperty, "top-level 'availability_zone' invalid when specifying subnets"
          end

          if network_spec.has_key?('cloud_properties')
            raise NetworkInvalidProperty, "top-level 'cloud_properties' invalid when specifying subnets"
          end

          subnets = network_spec['subnets'].map do |subnet_properties|
            dns = dns_servers(subnet_properties['name'], subnet_properties)
            cloud_properties =
              safe_property(subnet_properties, 'cloud_properties', class: Hash, default: {})
            availability_zone = safe_property(subnet_properties, 'availability_zone', class: String, optional: true)
            unless availability_zone.nil? || availability_zones.any? { |az| az.name == availability_zone }
              raise Bosh::Director::NetworkSubnetUnknownAvailabilityZone, "Network '#{name}' refers to an unknown availability zone '#{availability_zone}'"
            end
            DynamicNetworkSubnet.new(dns, cloud_properties, availability_zone)
          end
        else
          cloud_properties = safe_property(network_spec, 'cloud_properties', class: Hash, default: {})
          availability_zone = safe_property(network_spec, 'availability_zone', class: String, optional: true)
          unless availability_zone.nil? || availability_zones.any? { |az| az.name == availability_zone }
            raise Bosh::Director::NetworkSubnetUnknownAvailabilityZone, "Network '#{name}' refers to an unknown availability zone '#{availability_zone}'"
          end
          dns = dns_servers(network_spec['name'], network_spec)
          subnets = [DynamicNetworkSubnet.new(dns, cloud_properties, availability_zone)]
        end

        new(name, canonical_name, subnets, logger)
      end

      def initialize(name, canonical_name, subnets, logger)
        @name = name
        @canonical_name = canonical_name
        @subnets = subnets
        @logger = logger
      end

      attr_reader :name, :canonical_name, :subnets

      ##
      # Returns the network settings for the specific reservation.
      #
      # @param [NetworkReservation] reservation
      # @param [Array<String>] default_properties
      # @return [Hash] network settings that will be passed to the BOSH Agent
      def network_settings(reservation, default_properties = Network::VALID_DEFAULTS)
        if reservation.type != DynamicNetworkReservation
          raise NetworkReservationWrongType,
            "IP '#{format_ip(reservation.ip)}' on network '#{reservation.network.name}' does not belong to dynamic pool"
        end

        subnet = subnets.first # TODO: care about AZ someday

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

      def validate_has_job!(az_names, job_name)
        # nothing to validate
      end
    end
  end
end
