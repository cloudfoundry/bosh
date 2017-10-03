module Bosh::Director
  module DeploymentPlan
    module Steps
      class PreCleanupStep
        def initialize(logger, deployment_plan)
          @logger = logger
          @deployment_plan = deployment_plan
        end

        def perform
          delete_instances_for_obsolete_instance_groups
        end

        private

        def delete_instances_for_obsolete_instance_groups
          @logger.info('Deleting no longer needed instances')

	   all_obsolete_plans = @deployment_plan.all_obsolete

          if !all_obsolete_plans.empty?
            event_log_stage = Config.event_log.begin_stage('Deleting unneeded instances', all_obsolete_plans.size)
            instance_deleter = InstanceDeleter.new(@deployment_plan.ip_provider, PowerDnsManagerProvider.create, DiskManager.new(@logger))

            instance_deleter.delete_instance_plans(all_obsolete_plans, event_log_stage)
            @logger.info('Deleted no longer needed instances')
	   else
            @logger.info('No unneeded instances to delete')
          end
        end
      end
    end
  end
end
