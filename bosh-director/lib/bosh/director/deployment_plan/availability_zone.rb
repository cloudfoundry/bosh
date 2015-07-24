
module Bosh::Director
  module DeploymentPlan
    class AvailabilityZone
      include ValidationHelper

      attr_reader :name

      attr_reader :cloud_properties

      # @param [DeploymentPlan] deployment_plan Deployment plan
      # @param [Hash] spec Raw availability zone spec from the deployment manifest
      # @param [Logger] logger Director logger
      def initialize(availability_zone_spec)

        @name = safe_property(availability_zone_spec, "name", class: String)

        @cloud_properties =
          safe_property(availability_zone_spec, "cloud_properties", class: Hash, default: {})
      end
    end
  end
end
