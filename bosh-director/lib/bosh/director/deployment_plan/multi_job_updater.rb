module Bosh::Director
  module DeploymentPlan
    class SerialMultiJobUpdater
      def run(base_job, deployment_plan, jobs)
        jobs.each do |j|
          base_job.task_checkpoint
          base_job.logger.info("Updating job: #{j.name}")
          job_updater = JobUpdater.new(deployment_plan, j)
          job_updater.update
        end
      end
    end
  end
end
