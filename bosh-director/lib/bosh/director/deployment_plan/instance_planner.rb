module Bosh
  module Director
    module DeploymentPlan
      class InstancePlanFactory
        def initialize(instance_repo, states_by_existing_instance, skip_drain_decider, index_assigner, options = {})
          @instance_repo = instance_repo
          @skip_drain_decider = skip_drain_decider
          @recreate_deployment = options.fetch('recreate', false)
          @states_by_existing_instance = states_by_existing_instance
          @index_assigner = index_assigner
        end

        def obsolete_instance_plan(existing_instance_model)
          InstancePlan.new(
            desired_instance: nil,
            existing_instance: existing_instance_model,
            instance: nil,
            skip_drain: @skip_drain_decider.for_job(existing_instance_model.job),
            recreate_deployment: @recreate_deployment
          )
        end

        def desired_existing_instance_plan(existing_instance_model, desired_instance)
          existing_instance_state = @states_by_existing_instance[existing_instance_model]

          desired_instance.index = @index_assigner.assign_index(desired_instance.job.name, existing_instance_model)

          instance = @instance_repo.fetch_existing(desired_instance, existing_instance_model, existing_instance_state)
          instance.update_description
          InstancePlan.new(
            desired_instance: desired_instance,
            existing_instance: existing_instance_model,
            instance: instance,
            skip_drain: @skip_drain_decider.for_job(desired_instance.job.name),
            recreate_deployment: @recreate_deployment
          )
        end

        def desired_new_instance_plan(desired_instance)
          desired_instance.index = @index_assigner.assign_index(desired_instance.job.name)

          instance = @instance_repo.create(desired_instance, desired_instance.index)
          InstancePlan.new(
            desired_instance: desired_instance,
            existing_instance: nil,
            instance: instance,
            skip_drain: @skip_drain_decider.for_job(desired_instance.job.name),
            recreate_deployment: @recreate_deployment
          )
        end
      end

      class InstancePlanner
        def initialize(instance_plan_factory, logger)
          @instance_plan_factory = instance_plan_factory
          @logger = logger
        end

        def plan_job_instances(job, desired_instances, existing_instance_models)
          placement_plan = PlacementPlanner::Plan.new(@instance_plan_factory, @logger)
          instance_plans = placement_plan.create_instance_plans(desired_instances, existing_instance_models, job.networks, job.availability_zones, job.name)

          new_desired_instance_plans = instance_plans.select(&:new?)
          desired_existing_instance_plans = instance_plans.select(&:existing?)
          obsolete_existing_instance_plans = instance_plans.select(&:obsolete?)
          log_outcome(new_desired_instance_plans, desired_existing_instance_plans, obsolete_existing_instance_plans)

          elect_bootstrap_instance(new_desired_instance_plans, desired_existing_instance_plans)

          instance_plans
        end

        def plan_obsolete_jobs(desired_jobs, existing_instances)
          desired_job_names = Set.new(desired_jobs.map(&:name))
          migrating_job_names = Set.new(desired_jobs.map(&:migrated_from).flatten.map(&:name))
          existing_instances.reject do |existing_instance_model|
            desired_job_names.include?(existing_instance_model.job) ||
            migrating_job_names.include?(existing_instance_model.job)
          end.map do |existing_instance|
            @instance_plan_factory.obsolete_instance_plan(existing_instance)
          end
        end

        private

        def elect_bootstrap_instance(new_desired_instance_plans, desired_existing_instance_plans)
          bootstrap_instance_plans = desired_existing_instance_plans.select { |i| i.instance.bootstrap? }

          if bootstrap_instance_plans.size == 1
            bootstrap_instance_plan = bootstrap_instance_plans.first

            instance = bootstrap_instance_plan.instance
            @logger.info("Found existing bootstrap instance '#{instance}' in az '#{bootstrap_instance_plan.desired_instance.availability_zone}'")
          else
            all_desired_instance_plans = new_desired_instance_plans + desired_existing_instance_plans
            return if all_desired_instance_plans.empty?

            if bootstrap_instance_plans.size > 1
              @logger.info('Found multiple existing bootstrap instances. Going to pick a new bootstrap instance.')
            else
              @logger.info('No existing bootstrap instance. Going to pick a new bootstrap instance.')
            end
            lowest_indexed_desired_instance_plan = all_desired_instance_plans
                                                     .reject { |instance_plan| instance_plan.desired_instance.index.nil? }
                                                     .sort_by { |instance_plan| instance_plan.desired_instance.index }
                                                     .first

            all_desired_instance_plans.each do |instance_plan|
              instance = instance_plan.instance
              if instance_plan == lowest_indexed_desired_instance_plan
                @logger.info("Marking new bootstrap instance '#{instance}' in az '#{instance_plan.desired_instance.availability_zone}'")
                instance.mark_as_bootstrap
              else
                instance.unmark_as_bootstrap
              end
            end
          end
        end

        def log_outcome(new_desired_instance_plans, desired_existing_instance_plans, obsolete_existing_instance_plans)
          new_desired_instance_plans.each do |instance_plan|
            instance = instance_plan.desired_instance
            @logger.info("New desired instance '#{instance.job.name}/#{instance.index}' in az '#{instance.availability_zone}'")
          end

          desired_existing_instance_plans.each do |instance_plan|
            instance = instance_plan.existing_instance
            @logger.info("Existing desired instance '#{instance.job}/#{instance.index}' in az '#{instance_plan.desired_instance.availability_zone}'")
          end

          obsolete_existing_instance_plans.each do |instance_plan|
            instance = instance_plan.existing_instance
            @logger.info("Obsolete instance '#{instance.job}/#{instance.index}' in az '#{instance.availability_zone}'")
          end
        end
      end
    end
  end
end
