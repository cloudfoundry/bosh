module Bosh::Director
  module DeploymentPlan
    module Steps
      class SetupStep
        def initialize(base_job, deployment_plan, vm_creator)
          @base_job = base_job
          @logger = base_job.logger
          @deployment_plan = deployment_plan
          @vm_creator = vm_creator
        end

        def perform
          create_vms
        end

        private

        def create_vms
          @logger.info('Creating missing VMs')

          missing_plans = @deployment_plan.instance_plans_with_missing_vms
          hotswap_plans = @deployment_plan.instance_plans_with_hot_swap_and_needs_shutdown

          @vm_creator.create_for_instance_plans(
            missing_plans + hotswap_plans,
            @deployment_plan.ip_provider,
            @deployment_plan.tags
          )

          @base_job.task_checkpoint
        end
      end
    end
  end
end
