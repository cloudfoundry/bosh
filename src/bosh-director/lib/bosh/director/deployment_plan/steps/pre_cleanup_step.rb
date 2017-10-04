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

	   obsolete_plans = @deployment_plan.instance_plans_for_obsolete_instance_groups

          if !obsolete_plans.empty?
            event_log_stage = Config.event_log.begin_stage('Deleting unneeded instances', obsolete_plans.size)
            dns_encoder = LocalDnsEncoderManager.create_dns_encoder(@deployment_plan.use_short_dns_addresses?)
            instance_deleter = InstanceDeleter.new(@deployment_plan.ip_provider, PowerDnsManagerProvider.create, DiskManager.new(@logger, @deployment_plan.template_blob_cache, dns_encoder))

            instance_deleter.delete_instance_plans(obsolete_plans, event_log_stage)
            @logger.info('Deleted no longer needed instances')
	   else
            @logger.info('No unneeded instances to delete')
          end
        end
      end
    end
  end
end
