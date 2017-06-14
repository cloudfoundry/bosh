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
          delete_instances_for_obsolete_instance_groups
        end

        private

        def delete_instances_for_obsolete_instance_groups
          @logger.info('Deleting no longer needed instances')

          obsolete_instance_plans = @deployment_plan.instance_plans_for_obsolete_instance_groups
          if obsolete_instance_plans.empty?
            @logger.info('No unneeded instances to delete')
            return
          end
          event_log_stage = Config.event_log.begin_stage('Deleting unneeded instances', obsolete_instance_plans.size)
          instance_deleter = InstanceDeleter.new(@deployment_plan.ip_provider, PowerDnsManagerProvider.create, DiskManager.new(@logger))
          instance_deleter.delete_instance_plans(obsolete_instance_plans, event_log_stage)
          @logger.info('Deleted no longer needed instances')
        end
      end
    end
  end
end
