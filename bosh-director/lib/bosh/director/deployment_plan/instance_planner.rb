module Bosh
  module Director
    module DeploymentPlan
      class InstancePlanner
        def initialize(logger)
          @logger = logger
        end

        def create_instance_plans(existing_instances, desired_instances)
          plans_for_desired_instances = desired_instances.group_by(&:job).flat_map do |job, desired_instances_for_job|
            instance_plans = plan_job_instances(job, desired_instances_for_job, existing_instances)
            instance_plans
          end

          used_existing_instances = Set.new(plans_for_desired_instances.reject(&:new?).map(&:existing_instance))
          obsolete_existing_instance = Set.new(existing_instances).difference(used_existing_instances)

          plans_for_obsolete_instances = obsolete_existing_instance.map do |instance_model|
            instance = ExistingInstance.create_from_model(instance_model, @logger)
            InstancePlan.new(instance: instance, obsolete: true, existing_instance: instance_model)
          end

          plans_for_desired_instances + plans_for_obsolete_instances
        end

        private

        def plan_job_instances(job, desired_instances, existing_instances)
          desired_instances.map do |desired_instance|
            # TODO: look at job AZs eventually
            existing_instance = existing_instances.find do |existing_instance|
              existing_instance.job == desired_instance.job.name &&
                existing_instance.index == desired_instance.index
            end

            if existing_instance
              InstancePlan.new(instance: desired_instance, existing_instance: existing_instance)
            else
              InstancePlan.new(instance: desired_instance, existing_instance: nil)
            end
          end
        end
      end
    end
  end
end
