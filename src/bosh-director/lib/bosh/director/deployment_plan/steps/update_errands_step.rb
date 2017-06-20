module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateErrandsStep
        def initialize(base_job, deployment_plan)
          @base_job = base_job
          @logger = base_job.logger
          @event_log = Config.event_log
          @deployment_plan = deployment_plan
        end

        def perform
          delete_obsolete_errand_instances
          update_errands
        end

        private

        def delete_obsolete_errand_instances
          obsolete_instance_plans = @deployment_plan.errand_instance_groups.flat_map { |instance_group| instance_group.obsolete_instance_plans}

          if obsolete_instance_plans.empty?
            @logger.info('No unneeded errand instances to delete')
            return
          end

          event_log_stage = Config.event_log.begin_stage('Deleting unneeded errand instances', obsolete_instance_plans.size)

          @logger.info('Deleting no longer needed errand instances')
          instance_deleter = InstanceDeleter.new(@deployment_plan.ip_provider, PowerDnsManagerProvider.create, DiskManager.new(@logger))
          instance_deleter.delete_instance_plans(obsolete_instance_plans, event_log_stage)

          @logger.info('Deleted no longer needed errand instances')
        end

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
