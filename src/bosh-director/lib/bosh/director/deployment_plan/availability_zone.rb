module Bosh::Director
  module DeploymentPlan
    class AvailabilityZone
      extend ValidationHelper

      def self.parse(availability_zone_spec)
        name = safe_property(availability_zone_spec, "name", class: String)

        cloud_properties =
          safe_property(availability_zone_spec, "cloud_properties", class: Hash, default: {})

        cpi = safe_property(availability_zone_spec, "cpi", class: String, optional: true)

        new(name, cloud_properties, cpi)
      end

      def initialize(name, cloud_properties, cpi=nil)
        @name = name
        @cloud_properties = cloud_properties
        @cpi = cpi
      end

      attr_reader :name, :cloud_properties, :cpi

      def inspect
        "az: #{name}"
      end
    end
  end
end
