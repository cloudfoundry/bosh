module Bosh::Director
  module DeploymentPlan
    class AvailabilityZone
      extend ValidationHelper

      def self.parse(availability_zone_spec)
        name = safe_property(availability_zone_spec, "name", class: String)

        cloud_properties =
          safe_property(availability_zone_spec, "cloud_properties", class: Hash, default: {})

        new(name, cloud_properties)
      end

      def initialize(name, cloud_properties)
        @name = name
        @cloud_properties = cloud_properties
      end

      attr_reader :name, :cloud_properties

      def inspect
        "az: #{name}"
      end
    end
  end
end
