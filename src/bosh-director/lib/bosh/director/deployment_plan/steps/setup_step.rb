module Bosh::Director
  module DeploymentPlan
    module Steps
      class SetupStep
        def initialize(base_job, deployment_plan, vm_creator, local_dns_repo, dns_publisher)
          @base_job = base_job
          @logger = base_job.logger
          @deployment_plan = deployment_plan
          @vm_creator = vm_creator
          @local_dns_repo = local_dns_repo
          @dns_publisher = dns_publisher
        end

        def perform
          push_any_new_azs(@deployment_plan.availability_zone_names)
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

          missing_plans.each do |plan|
            @local_dns_repo.update_for_instance(plan.instance.model)
          end
          @dns_publisher.publish_and_broadcast

          @base_job.task_checkpoint
        end

        def push_any_new_azs(az_names)
          az_names.each do |az|
            begin
              Models::AvailabilityZone.create({'name' => az})
            rescue Sequel::UniqueConstraintViolation => e
            end
          end
        end

      end
    end
  end
end
