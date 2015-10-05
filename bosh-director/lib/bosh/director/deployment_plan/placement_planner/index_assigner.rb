module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class IndexAssigner
          def assign_indexes(zoned_instances)
            desired_existing_instances = zoned_instances[:desired_existing]
            desired_new = zoned_instances[:desired_new]
            obsolete = zoned_instances[:obsolete]
            count = desired_new.count + desired_existing_instances.count + obsolete.count
            candidate_indexes = (0..count).to_a

            obsolete.each do |instance_model|
              candidate_indexes.delete(instance_model.index)
            end

            existing_indexes = []
            desired_existing_instances.each do |desired_existing_instance|
              existing_instance_model = desired_existing_instance[:existing_instance_model]
              desired_instance = desired_existing_instance[:desired_instance]
              candidate_indexes.delete(existing_instance_model.index)
              if existing_indexes.include?(existing_instance_model.index)
                desired_instance.index = candidate_indexes.shift
              else
                desired_instance.index = existing_instance_model.index
              end
              existing_indexes << existing_instance_model.index
            end

            desired_new.each do |desired_instance|
              desired_instance.index = candidate_indexes.shift
            end
          end
        end
      end
    end
  end
end
