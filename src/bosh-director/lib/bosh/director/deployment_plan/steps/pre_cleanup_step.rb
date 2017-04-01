module Bosh::Director
  module DeploymentPlan
    module Steps
      class PreCleanupStep
        def initialize(base_job, deployment_plan)
          @base_job = base_job
          @logger = base_job.logger
          @deployment_plan = deployment_plan
        end

        def perform
          delete_unneeded_instances
        end

        private

        def delete_unneeded_instances
          @logger.info('Deleting no longer needed instances')

          unneeded_instance_plans = @deployment_plan.unneeded_instance_plans
          if unneeded_instance_plans.empty?
            @logger.info('No unneeded instances to delete')
            return
          end
          event_log_stage = Config.event_log.begin_stage('Deleting unneeded instances', unneeded_instance_plans.size)
          instance_deleter = InstanceDeleter.new(@deployment_plan.ip_provider, DnsManagerProvider.create, DiskManager.new(@logger))
          instance_deleter.delete_instance_plans(unneeded_instance_plans, event_log_stage)
          @logger.info('Deleted no longer needed instances')
        end
      end
    end
  end
end
