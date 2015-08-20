module Bosh
  module Director
    module DeploymentPlan
      class InstancePlanner
        def initialize(logger, instance_factory)
          @logger = logger
          @instance_repo = instance_factory
          @availability_zone_picker = AvailabilityZonePicker.new
        end

        def plan_job_instances(job, desired_instances, existing_instances, states_by_existing_instance)
          availability_zones = job.availability_zones

          results = @availability_zone_picker.place_and_match_instances(availability_zones, desired_instances, existing_instances)

          count = results[:desired].count + results[:obsolete].count
          candidate_indexes = (0..count).to_a

          zoned_desired_instances = results[:desired]
          new_desired_instances = zoned_desired_instances.select do |desired_instance|
            desired_instance.instance.nil?
          end
          existing_desired_instances = zoned_desired_instances - new_desired_instances

          new_desired_instances.each do |desired_instance|
            @logger.info("New desired instance: #{desired_instance.job.name} in az: #{az_name_for_desired_instance(desired_instance)}")
          end

          existing_desired_instances.each do |desired_instance|
            @logger.info("Existing desired instance: #{desired_instance.job.name}/#{desired_instance.instance.index} in az: #{az_name_for_desired_instance(desired_instance)}")
          end

          results[:obsolete].each do |instance|
            @logger.info("Obsolete instance: #{instance.job}/#{instance.index} in az: #{instance.availability_zone}")
          end

          desired_existing_instance_plans = desired_existing_instance_plans(existing_desired_instances, states_by_existing_instance, candidate_indexes)
          obsolete_instance_plans = obsolete_instance_plans(results[:obsolete], candidate_indexes)
          desired_new_instance_plans = desired_new_instance_plans(job, new_desired_instances, candidate_indexes)

          desired_existing_instance_plans + desired_new_instance_plans + obsolete_instance_plans
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

        def az_name_for_desired_instance(desired_instance)
          desired_instance.az.name unless desired_instance.az.nil?
        end

        def obsolete_instance_plans(obsolete_desired_instances, candidate_indexes)
          obsolete_desired_instances.map do |existing_instance|
            @logger.debug("Obsolete existing instance #{existing_instance}")
            instance = @instance_repo.fetch_obsolete(existing_instance, @logger)
            candidate_indexes.delete(existing_instance.index)
            InstancePlan.new(desired_instance: nil, existing_instance: existing_instance, instance: instance)
          end
        end

        def desired_existing_instance_plans(existing_desired_instances, states_by_existing_instance, candidate_indexes)
          existing_desired_instances.map do |desired_instance|
            existing_instance = desired_instance.instance
            @logger.debug("Found existing instance #{existing_instance}")
            candidate_indexes.delete(existing_instance.index)
            existing_instance_state = states_by_existing_instance[existing_instance]
            instance = @instance_repo.fetch_existing(desired_instance, existing_instance_state, existing_instance.index, @logger)
            InstancePlan.new(desired_instance: desired_instance, existing_instance: existing_instance, instance: instance)
          end
        end

        def desired_new_instance_plans(job, new_desired_instances, candidate_indexes)
          new_desired_instances.map do |desired_instance|
            @logger.debug("Creating a new instance for desired instance #{job.name}")
            index = candidate_indexes.shift
            instance = @instance_repo.create(desired_instance, index, @logger)
            InstancePlan.new(desired_instance: desired_instance, existing_instance: nil, instance: instance)
          end
        end

      end
    end
  end
end
