module Bosh
  module Director
    module DeploymentPlan
      class InstancePlanner
        def initialize(logger)
          @logger = logger
        end

        def plan_job_instances(job, desired_instances, existing_instances)
          desired_instance_plans = desired_instances.map do |desired_instance|
            # TODO: look at job AZs eventually
            existing_instance = existing_instances.find do |existing_instance|
              existing_instance.job == desired_instance.job.name &&
                existing_instance.index == desired_instance.index
            end

            if existing_instance
              desired_instance.bind_existing_instance_model(existing_instance)
              InstancePlan.new(desired_instance: desired_instance, existing_instance: existing_instance, instance: desired_instance)
            else
              desired_instance.bind_new_instance_model
              InstancePlan.new(desired_instance: desired_instance, existing_instance: nil, instance: desired_instance)
            end
          end

          obsolete_existing_instances = (existing_instances - desired_instance_plans.map(&:existing_instance))
          obsolete_instance_plans = obsolete_existing_instances.map do |existing_instance|
            instance = ExistingInstance.create_from_model(existing_instance, @logger)
            InstancePlan.new(desired_instance: nil, existing_instance: existing_instance, instance: instance)
          end

          desired_instance_plans + obsolete_instance_plans
        end

        def plan_obsolete_jobs(desired_jobs, existing_instances)
          desired_job_names = Set.new(desired_jobs.map(&:name))
          existing_instances.reject do |existing_instance_model|
            desired_job_names.include?(existing_instance_model.job)
          end.map do |existing_instance|
            instance = ExistingInstance.create_from_model(existing_instance, @logger)
            InstancePlan.new(desired_instance: nil, existing_instance: existing_instance, instance: instance)
          end
        end
      end
    end
  end
end
