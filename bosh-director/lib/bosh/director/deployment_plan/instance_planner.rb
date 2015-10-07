module Bosh
  module Director
    module DeploymentPlan
      class InstancePlanner
        def initialize(logger, instance_factory)
          @logger = logger
          @instance_repo = instance_factory
        end

        def plan_job_instances(job, desired_instances, existing_instances_with_azs, states_by_existing_instance)
          placement_plan = PlacementPlanner::Plan.new(desired_instances, existing_instances_with_azs, job.networks, job.availability_zones)

          new_desired_instances = placement_plan.needed
          desired_existing_instances = placement_plan.existing
          obsolete_instance_models = placement_plan.obsolete

          log_outcome(placement_plan)

          elect_bootstrap_instance(new_desired_instances, desired_existing_instances)

          desired_new_instance_plans = desired_new_instance_plans(new_desired_instances)
          desired_existing_instance_plans = desired_existing_instance_plans(desired_existing_instances, states_by_existing_instance)
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
            InstancePlan.new(desired_instance: nil, existing_instance: existing_instance, instance: nil)
          end
        end

        private

        def elect_bootstrap_instance(new_desired_instances, desired_existing_instances)
          bootstrap_instances = desired_existing_instances.select { |i| i[:existing_instance_model].bootstrap }

          if bootstrap_instances.size == 1
            bootstrap_instance = bootstrap_instances.first
            bootstrap_instance_model = bootstrap_instance[:existing_instance_model]
            bootstrap_desired_instance = bootstrap_instance[:desired_instance]

            @logger.info("Found existing bootstrap instance: #{bootstrap_instance_model.job}/#{bootstrap_instance_model.index} in az: #{bootstrap_instance_model.availability_zone}")
            bootstrap_desired_instance.mark_as_bootstrap
          else
            all_desired_instances = new_desired_instances + desired_existing_instances.map { |i| i[:desired_instance] }
            return if all_desired_instances.empty?

            if bootstrap_instances.size > 1
              @logger.info('Found multiple existing bootstrap instances. Going to pick a new bootstrap instance.')
            else
              @logger.info('No existing bootstrap instance. Going to pick a new bootstrap instance.')
            end
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
        end

        def az_name_for_instance(instance)
          instance.availability_zone
        end

        def obsolete_instance_plans(obsolete_desired_instances)
          obsolete_desired_instances.map do |existing_instance|
            InstancePlan.new(desired_instance: nil, existing_instance: existing_instance, instance: nil)
          end
        end

        def desired_existing_instance_plans(existing_instances_and_deployment, states_by_existing_instance)
          existing_instances_and_deployment.map do |existing_instance_and_deployment|
            existing_instance_model = existing_instance_and_deployment[:existing_instance_model]
            desired_instance = existing_instance_and_deployment[:desired_instance]
            existing_instance_state = states_by_existing_instance[existing_instance_model]
            instance = @instance_repo.fetch_existing(desired_instance, existing_instance_model, existing_instance_state)
            InstancePlan.new(desired_instance: desired_instance, existing_instance: existing_instance_model, instance: instance)
          end
        end

        def desired_new_instance_plans(new_desired_instances)
          new_desired_instances.map do |desired_instance|
            instance = @instance_repo.create(desired_instance, desired_instance.index)
            InstancePlan.new(desired_instance: desired_instance, existing_instance: nil, instance: instance)
          end
        end

        def log_outcome(placement_plan)
          new_desired_instances = placement_plan.needed
          desired_existing_instances = placement_plan.existing
          existing_instance_models = desired_existing_instances.map{ |instance_and_deployment| instance_and_deployment[:existing_instance_model] }
          obsolete_instance_models = placement_plan.obsolete

          new_desired_instances.each do |desired_instance|
            @logger.info("New desired instance: #{desired_instance.job.name} in az: #{az_name_for_instance(desired_instance)}")
          end

          existing_instance_models.each do |existing_instance_model|
            @logger.info("Existing desired instance: #{existing_instance_model.job}/#{existing_instance_model.index} in az: #{az_name_for_instance(existing_instance_model)}")
          end

          obsolete_instance_models.each do |instance|
            @logger.info("Obsolete instance: #{instance.job}/#{instance.index} in az: #{instance.availability_zone}")
          end
        end
      end
    end
  end
end
