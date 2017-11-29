module Bosh::Director
  module DeploymentPlan
    module Stages
      class UpdateJobsStage
        def initialize(base_job, deployment_plan, multi_job_updater)
          @base_job = base_job
          @logger = base_job.logger
          @deployment_plan = deployment_plan
          @multi_job_updater = multi_job_updater
        end

        def perform
          update_jobs
        end

        private

        def update_jobs
          @logger.info('Updating instances')
          @multi_job_updater.run(
            @base_job,
            @deployment_plan.ip_provider,
            @deployment_plan.instance_groups,
          )
        end
      end
    end
  end
end
