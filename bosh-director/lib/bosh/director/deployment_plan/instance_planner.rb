module Bosh
  module Director
    module DeploymentPlan
      class InstancePlanner
        def initialize(instance_plan_factory, logger)
          @instance_plan_factory = instance_plan_factory
          @logger = logger
        end

        def plan_job_instances(job, desired_instances, existing_instance_models)

          ignored_instances_count = existing_instance_models.count{ |instance| instance.ignore }
          if ignored_instances_count > 0
            @logger.info("Found #{ignored_instances_count} ignored instance(s). Will avoid doing any changes to them.")
            fail_if_specifically_changing_state_of_ignored_vms(job, existing_instance_models)
            desired_instances, existing_instance_models = reject_ignored_instances_and_modify_desired_instances(desired_instances, existing_instance_models, ignored_instances_count)
          end

          network_planner = NetworkPlanner::Planner.new(@logger)
          placement_plan = PlacementPlanner::Plan.new(@instance_plan_factory, network_planner, @logger)
          vip_networks, non_vip_networks = job.networks.to_a.partition(&:vip?)
          instance_plans = placement_plan.create_instance_plans(desired_instances, existing_instance_models, non_vip_networks, job.availability_zones, job.name)

          log_outcome(instance_plans)

          desired_instance_plans = instance_plans.reject(&:obsolete?)
          vip_static_ips_planner = NetworkPlanner::VipStaticIpsPlanner.new(network_planner, @logger)
          vip_static_ips_planner.add_vip_network_plans(desired_instance_plans, vip_networks)
          reconcile_network_plans(desired_instance_plans)

          elect_bootstrap_instance(desired_instance_plans)

          instance_plans
        end

        def plan_obsolete_jobs(desired_jobs, existing_instances)
          desired_job_names = Set.new(desired_jobs.map(&:name))
          migrating_job_names = Set.new(desired_jobs.map(&:migrated_from).flatten.map(&:name))
          obsolete_existing_instances = existing_instances.reject do |existing_instance_model|
            desired_job_names.include?(existing_instance_model.job) ||
              migrating_job_names.include?(existing_instance_model.job)
          end

          obsolete_existing_instances.each do |instance_model|
            if instance_model.ignore
              raise DeploymentIgnoredInstancesDeletion, "You are trying to delete instance group '#{instance_model.job}', which " +
                  'contains ignored instance(s). Operation not allowed.'
            end
          end

          obsolete_existing_instances.map do |obsolete_existing_instance|
            @instance_plan_factory.obsolete_instance_plan(obsolete_existing_instance)
          end
        end

        def reject_ignored_instances_and_modify_desired_instances(desired_instances, existing_instance_models, ignored_instances_count)
          if desired_instances.count == existing_instance_models.count
            @logger.info("Desired instances count, #{desired_instances.count}, is equal to existing instances, #{existing_instance_models.count}")
            modified_existing_instance_models =  existing_instance_models.reject{ |instance| instance.ignore }
            modified_desired_instances = desired_instances.slice(0, modified_existing_instance_models.length)
          elsif desired_instances.count > existing_instance_models.count
            @logger.info("Desired instances count, #{desired_instances.count}, is greater than existing instances, #{existing_instance_models.count}")
            modified_existing_instance_models =  existing_instance_models.reject{ |instance| instance.ignore }
            modified_desired_instances = desired_instances.slice(0, desired_instances.length - ignored_instances_count)
          else
            @logger.info("Desired instances count, #{desired_instances.count}, is less than existing instances, #{existing_instance_models.count}")
            if ignored_instances_count > desired_instances.count
              raise DeploymentIgnoredInstancesModification, "Instance Group '#{existing_instance_models.first.job}' has #{ignored_instances_count} ignored instances." +
                  "You requested to have #{desired_instances.count} instances of that instance group. Deleting ignored instances is not allowed."
            elsif ignored_instances_count == desired_instances.count
              @logger.info("Ignored instances count, #{ignored_instances_count}, is equal to desired instances, #{desired_instances.count}")
              modified_existing_instance_models =  existing_instance_models.reject{ |instance| instance.ignore }
              modified_desired_instances = []
            else
              @logger.info("Ignored instances count, #{ignored_instances_count}, is less than desired instances, #{desired_instances.count}")
              modified_existing_instance_models =  existing_instance_models.reject{ |instance| instance.ignore }
              modified_desired_instances = desired_instances.slice(0, desired_instances.length - ignored_instances_count)
            end
          end

          return modified_desired_instances, modified_existing_instance_models
        end

        private

        def elect_bootstrap_instance(desired_instance_plans)
          bootstrap_instance_plans = desired_instance_plans.select { |i| i.instance.bootstrap? }

          if bootstrap_instance_plans.size == 1
            bootstrap_instance_plan = bootstrap_instance_plans.first

            instance = bootstrap_instance_plan.instance
            @logger.info("Found existing bootstrap instance '#{instance}' in az '#{bootstrap_instance_plan.desired_instance.availability_zone}'")
          else
            return if desired_instance_plans.empty?

            if bootstrap_instance_plans.size > 1
              @logger.info('Found multiple existing bootstrap instances. Going to pick a new bootstrap instance.')
            else
              @logger.info('No existing bootstrap instance. Going to pick a new bootstrap instance.')
            end
            lowest_indexed_desired_instance_plan = desired_instance_plans
                                                     .reject { |instance_plan| instance_plan.desired_instance.index.nil? }
                                                     .sort_by { |instance_plan| instance_plan.desired_instance.index }
                                                     .first

            desired_instance_plans.each do |instance_plan|
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

        def reconcile_network_plans(instance_plans)
          instance_plans.each do |instance_plan|
            network_plans = NetworkPlanner::ReservationReconciler.new(instance_plan, @logger)
                              .reconcile(instance_plan.instance.existing_network_reservations)
            instance_plan.network_plans = network_plans
          end
        end

        def fail_if_specifically_changing_state_of_ignored_vms(job, existing_instance_models)
          ignored_models = existing_instance_models.select{|instance| instance.ignore}
          ignored_models.each do |model|
            unless job.instance_states["#{model.index}"].nil?
              raise JobInstanceIgnored, "You are trying to change the state of the ignored instance '#{model.job}/#{model.uuid}'. " +
                  'This operation is not allowed. You need to unignore it first.'
            end
          end
        end

        def log_outcome(instance_plans)
          instance_plans.select(&:new?).each do |instance_plan|
            instance = instance_plan.desired_instance
            @logger.info("New desired instance '#{instance.job.name}/#{instance.index}' in az '#{instance.availability_zone}'")
          end

          instance_plans.select(&:existing?).each do |instance_plan|
            instance = instance_plan.existing_instance
            @logger.info("Existing desired instance '#{instance.job}/#{instance.index}' in az '#{instance_plan.desired_instance.availability_zone}'")
          end

          instance_plans.select(&:obsolete?).each do |instance_plan|
            instance = instance_plan.existing_instance
            @logger.info("Obsolete instance '#{instance.job}/#{instance.index}' in az '#{instance.availability_zone}'")
          end
        end
      end
    end
  end
end
