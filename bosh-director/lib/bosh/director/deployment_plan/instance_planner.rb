module Bosh
  module Director
    module DeploymentPlan
      class InstancePlanner
        def initialize(logger, instance_factory)
          @logger = logger
          @instance_repo = instance_factory
        end

        def plan_job_instances(job, desired_instances, existing_instances)
          unbound_existing_instances = Set.new(existing_instances)
          desired_instance_plans = desired_instances.each_with_index.map do |desired_instance, index|
            existing_instance = find_matching_instance(job, unbound_existing_instances, desired_instance)
            unless existing_instance.nil?
              unbound_existing_instances.delete(existing_instance)
            end

            availability_zone = AvailabilityZonePicker.new.pick_from(job.availability_zones, index)

            if existing_instance
              instance = @instance_repo.fetch_existing(desired_instance, existing_instance, index, availability_zone, @logger)
              InstancePlan.new(desired_instance: desired_instance, existing_instance: existing_instance, instance: instance)
            else
              instance = @instance_repo.create(desired_instance, index, availability_zone, @logger)
              InstancePlan.new(desired_instance: desired_instance, existing_instance: nil, instance: instance)
            end
          end

          obsolete_existing_instances = unbound_existing_instances.to_a
          obsolete_instance_plans = obsolete_existing_instances.map do |existing_instance|
            instance = @instance_repo.fetch_obsolete(existing_instance, @logger)
            InstancePlan.new(desired_instance: nil, existing_instance: existing_instance, instance: instance)
          end

          desired_instance_plans + obsolete_instance_plans
        end

        def plan_obsolete_jobs(desired_jobs, existing_instances)
          desired_job_names = Set.new(desired_jobs.map(&:name))
          existing_instances.reject do |existing_instance_model|
            desired_job_names.include?(existing_instance_model.job)
          end.map do |existing_instance|
            instance = @instance_repo.fetch_obsolete(existing_instance, @logger)
            InstancePlan.new(desired_instance: nil, existing_instance: existing_instance, instance: instance)
          end
        end

        private

        def find_matching_instance(job, existing_instances, desired_instance)
          existing_instances.sort_by(&:index).first
        end
      end
    end
  end
end
