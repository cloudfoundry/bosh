module Bosh::Director
  module DeploymentPlan
    class VmType
      include ValidationHelper

      attr_reader :name

      attr_reader :cloud_properties

      def initialize(spec)

        @name = safe_property(spec, "name", class: String)

        @cloud_properties =
          safe_property(spec, "cloud_properties", class: Hash, default: {})

      end

      def spec
        {
          "name" => @name,
          "cloud_properties" => @cloud_properties,
        }
      end
    end
  end
end
