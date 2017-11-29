module Bosh::Director
  module DeploymentPlan
    module Stages
      class UpdateErrandsStage
        def initialize(base_job, deployment_plan)
          @base_job = base_job
          @logger = base_job.logger
          @event_log = Config.event_log
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
