module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class IndexAssigner
          def assign_indexes(zoned_instances)
            desired_existing_instances = zoned_instances[:desired_existing]
            desired_new = zoned_instances[:desired_new]
            obsolete = zoned_instances[:obsolete]
            total_number_of_instances = desired_new.count + desired_existing_instances.count + obsolete.count
            candidate_indexes = (0..total_number_of_instances-1).to_a

            obsolete.each do |instance_model|
              candidate_indexes.delete(instance_model.index)
            end

            # prefer existing instances over migrating instances when picking index
            [
              matching_desired_existing_instances(desired_existing_instances),
              migrating_desired_existing_instances(desired_existing_instances)
            ].flatten.each do |desired_existing_instance|
              existing_instance_model = desired_existing_instance[:existing_instance_model]
              desired_instance = desired_existing_instance[:desired_instance]
              if candidate_indexes.delete(existing_instance_model.index) ||
                existing_instance_model.index > total_number_of_instances
                desired_instance.index = existing_instance_model.index
              else
                desired_instance.index = candidate_indexes.shift
              end
            end

            desired_new.each do |desired_instance|
              desired_instance.index = candidate_indexes.shift
            end
          end

          private

          def matching_desired_existing_instances(desired_existing_instances)
            desired_existing_instances.select do |desired_existing_instance|
              desired_existing_instance[:existing_instance_model].job ==
                desired_existing_instance[:desired_instance].job.name
            end
          end

          def migrating_desired_existing_instances(desired_existing_instances)
            desired_existing_instances.select do |desired_existing_instance|
              desired_existing_instance[:existing_instance_model].job !=
                desired_existing_instance[:desired_instance].job.name
            end
          end
        end
      end
    end
  end
end
