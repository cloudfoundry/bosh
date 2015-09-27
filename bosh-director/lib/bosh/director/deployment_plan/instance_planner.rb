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

          instances_by_type = @availability_zone_picker.place_and_match_in(availability_zones, desired_instances, existing_instances)

          new_desired_instances = instances_by_type[:desired_new]
          existing_instances = instances_by_type[:desired_existing].map{ |instance_and_deployment| instance_and_deployment[:existing_instance_model] }
          obsolete_instance_models = instances_by_type[:obsolete]

          new_desired_instances.each do |desired_instance|
            @logger.info("New desired instance: #{desired_instance.job.name} in az: #{az_name_for_instance(desired_instance)}")
          end

          existing_instances.each do |existing_instance|
            @logger.info("Existing desired instance: #{existing_instance.job}/#{existing_instance.index} in az: #{az_name_for_instance(existing_instance)}")
          end

          obsolete_instance_models.each do |instance|
            @logger.info("Obsolete instance: #{instance.job}/#{instance.index} in az: #{instance.availability_zone}")
          end

          all_desired_instances = new_desired_instances+existing_instances
          bootstrap_instance = existing_instances.find(&:bootstrap)
          @logger.info("Found existing bootstrap instance: #{bootstrap_instance.job}/#{bootstrap_instance.index} in az: #{bootstrap_instance.availability_zone}") if bootstrap_instance

          if bootstrap_instance.nil? && !all_desired_instances.empty?
            @logger.info('No existing bootstrap instance. Going to pick a new bootstrap instance.')
            lowest_indexed_desired_instance = all_desired_instances
                                                .reject { |instance| instance.index.nil? }
                                                .sort_by { |instance| instance.index }
                                                .first

            all_desired_instances.each do |instance|
              if instance == lowest_indexed_desired_instance
                @logger.info("Marking new bootstrap instance: #{instance.job}/#{instance.index} in az #{instance.availability_zone}")
                instance.mark_as_bootstrap
              end
            end
          end

          desired_new_instance_plans = desired_new_instance_plans(new_desired_instances)
          desired_existing_instance_plans = desired_existing_instance_plans(instances_by_type[:desired_existing], states_by_existing_instance)
          obsolete_instance_plans = obsolete_instance_plans(obsolete_instance_models)

          desired_existing_instance_plans + desired_new_instance_plans + obsolete_instance_plans
        end

        def plan_obsolete_jobs(desired_jobs, existing_instances)
          desired_job_names = Set.new(desired_jobs.map(&:name))
          migrating_job_names = Set.new(desired_jobs.map(&:migrated_from).flatten.map(&:name))
          existing_instances.reject do |existing_instance_model|
            desired_job_names.include?(existing_instance_model.job) ||
            migrating_job_names.include?(existing_instance_model.job)
          end.map do |existing_instance|
            instance = @instance_repo.fetch_obsolete(existing_instance, @logger)
            InstancePlan.new(desired_instance: nil, existing_instance: existing_instance, instance: instance)
          end
        end

        private

        def az_name_for_instance(instance)
          instance.availability_zone
        end

        def obsolete_instance_plans(obsolete_desired_instances)
          obsolete_desired_instances.map do |existing_instance|
            instance = @instance_repo.fetch_obsolete(existing_instance, @logger)
            InstancePlan.new(desired_instance: nil, existing_instance: existing_instance, instance: instance)
          end
        end

        def desired_existing_instance_plans(existing_instances_and_deployment, states_by_existing_instance)
          existing_instances_and_deployment.map do |existing_instance_and_deployment|
            existing_instance_model = existing_instance_and_deployment[:existing_instance_model]
            desired_instance = existing_instance_and_deployment[:desired_instance]
            existing_instance_state = states_by_existing_instance[existing_instance_model]
            instance = @instance_repo.fetch_existing(desired_instance, existing_instance_model, existing_instance_state, @logger)
            InstancePlan.new(desired_instance: desired_instance, existing_instance: existing_instance_model, instance: instance)
          end
        end

        def desired_new_instance_plans(new_desired_instances)
          new_desired_instances.map do |desired_instance|
            instance = @instance_repo.create(desired_instance, desired_instance.index, @logger)
            InstancePlan.new(desired_instance: desired_instance, existing_instance: nil, instance: instance)
          end
        end

      end
    end
  end
end
