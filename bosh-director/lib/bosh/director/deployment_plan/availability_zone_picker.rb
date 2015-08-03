module Bosh
  module Director
    module DeploymentPlan
      class AvailabilityZonePicker
        def pick_from(availability_zones, index)
          return nil if availability_zones.nil?
          availability_zones[index % availability_zones.count]
        end
      end
    end
  end
end
