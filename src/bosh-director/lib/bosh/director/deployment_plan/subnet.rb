module Bosh::Director
  module DeploymentPlan
    class Subnet
      extend ValidationHelper

      def self.parse_availability_zones(subnet_spec, network_name, availability_zones)
        has_availability_zones_key = subnet_spec.key?('azs')
        has_availability_zone_key = subnet_spec.key?('az')
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

      def self.check_validity_of_subnet_availability_zone(availability_zone_name, availability_zones, network_name)
        return if availability_zone_name.nil? || availability_zones.any? { |az| az.name == availability_zone_name }

        raise Bosh::Director::NetworkSubnetUnknownAvailabilityZone,
              "Network '#{network_name}' refers to an unknown availability zone '#{availability_zone_name}'"
      end
    end
  end
end
