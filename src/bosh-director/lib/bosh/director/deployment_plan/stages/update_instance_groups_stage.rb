module Bosh::Director
  module DeploymentPlan
    module Stages
      class UpdateInstanceGroupsStage
        def initialize(base_job, deployment_plan, multi_instance_group_updater)
          @base_job = base_job
          @logger = base_job.logger
          @deployment_plan = deployment_plan
          @multi_instance_group_updater = multi_instance_group_updater
        end

        def perform
          update_instance_groups
        end

        private

        def update_instance_groups
          @logger.info('Updating instances')
          @multi_instance_group_updater.run(
            @base_job,
            @deployment_plan.ip_provider,
            @deployment_plan.instance_groups,
          )
        end
      end
    end
  end
end
