module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class PlacedDesiredInstances
          attr_reader :absent, :existing

          def initialize(azs)
            @placed = {}
            (azs || []).each do |az|
              @placed[az] = []
            end

            @absent = []
            @existing = []
          end

          def record_placement(az, desired_instance, existing_instance_model)
            desired_instance.az = az
            @placed[az] = @placed.fetch(az, []) << desired_instance

            if existing_instance_model
              existing << {
                desired_instance: desired_instance,
                existing_instance_model: existing_instance_model
              }
            else
              absent << desired_instance
            end
          end

          def azs_with_fewest_instances
            az_with_fewest = @placed.keys.min_by { |az|@placed[az].size }
            @placed.keys.select { |az| (@placed[az].size == @placed[az_with_fewest].size) && az }
          end
        end
      end
    end
  end
end
