module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class IndexAssigner
          def initialize(deployment_model)
            @deployment_model = deployment_model
          end

          def assign_index(job_name, existing_instance_model=nil)
            if existing_instance_model && existing_instance_model.job == job_name
              return existing_instance_model.index
            end

            sorted_indexes = Models::Instance.filter(job: job_name, deployment: @deployment_model).sort_by(&:index).map(&:index)
            if sorted_indexes.empty?
              0
            else
              find_unused_index(sorted_indexes)
            end
          end

          def find_unused_index(sorted_indexes)
            sorted_indexes.unshift(-1)
            next_indexes = sorted_indexes.map { |i| i + 1 }
            (next_indexes - sorted_indexes).min
          end
        end
      end
    end
  end
end
