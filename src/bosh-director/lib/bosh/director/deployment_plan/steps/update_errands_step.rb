module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateErrandsStep
        def initialize(deployment_plan)
          @deployment_plan = deployment_plan
        end

        def perform
          update_errands
        end

        private

        def update_errands
          @deployment_plan.errand_instance_groups.each do |instance_group|
            instance_group.unignored_instance_plans.each do |instance_plan|
              instance_plan.instance.update_variable_set
            end
          end
        end
      end
    end
  end
end
