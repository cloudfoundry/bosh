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
          # TODO: something about instance_plans.select(&:new?) -- how does that compare to the isntance#has_vm check?
          @vm_creator.create_for_instance_plans(
            @deployment_plan.instance_plans_with_missing_vms,
            @deployment_plan.ip_provider,
            @deployment_plan.tags
          )

          @base_job.task_checkpoint
        end
      end
    end
  end
end
