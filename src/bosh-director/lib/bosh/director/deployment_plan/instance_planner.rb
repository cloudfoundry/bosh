module Bosh
  module Director
    module DeploymentPlan
      class InstancePlanner
        def initialize(instance_plan_factory, logger)
          @instance_plan_factory = instance_plan_factory
          @logger = logger
        end

        def plan_instance_group_instances(instance_group, desired_instances, existing_instance_models)
          if existing_instance_models.count(&:ignore) > 0
            fail_if_specifically_changing_state_of_ignored_vms(instance_group, existing_instance_models)
          end

          network_planner = NetworkPlanner::Planner.new(@logger)
          placement_plan = PlacementPlanner::Plan.new(@instance_plan_factory, network_planner, @logger)
          vip_networks, non_vip_networks = instance_group.networks.to_a.partition(&:vip?)
          instance_plans = placement_plan.create_instance_plans(desired_instances, existing_instance_models, non_vip_networks, instance_group.availability_zones, instance_group.name)

          log_outcome(instance_plans)

          desired_instance_plans = instance_plans.reject(&:obsolete?)
          vip_static_ips_planner = NetworkPlanner::VipStaticIpsPlanner.new(network_planner, @logger)
          vip_static_ips_planner.add_vip_network_plans(desired_instance_plans, vip_networks)
          reconcile_network_plans(desired_instance_plans)

          elect_bootstrap_instance(desired_instance_plans)

          instance_plans
        end

        def plan_obsolete_instance_groups(desired_instance_groups, existing_instances)
          desired_instance_group_names = Set.new(desired_instance_groups.map(&:name))
          migrating_instance_group_names = Set.new(desired_instance_groups.map(&:migrated_from).flatten.map(&:name))
          obsolete_existing_instances = existing_instances.reject do |existing_instance_model|
            desired_instance_group_names.include?(existing_instance_model.job) ||
              migrating_instance_group_names.include?(existing_instance_model.job)
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

        def fail_if_specifically_changing_state_of_ignored_vms(instance_group, existing_instance_models)
          ignored_models = existing_instance_models.select(&:ignore)
          ignored_models.each do |model|
            unless instance_group.instance_states["#{model.index}"].nil?
              raise JobInstanceIgnored, "You are trying to change the state of the ignored instance '#{model.job}/#{model.uuid}'. " +
                  'This operation is not allowed. You need to unignore it first.'
            end
          end
        end

        def log_outcome(instance_plans)
          instance_plans.select(&:new?).each do |instance_plan|
            desired_instance = instance_plan.desired_instance
            @logger.info("New desired instance '#{desired_instance.instance_group.name}/#{desired_instance.index}' in az '#{desired_instance.availability_zone}'")
          end

          instance_plans.select(&:existing?).each do |instance_plan|
            instance = instance_plan.existing_instance
            vm_activeness_msg = instance.active_vm ? "active vm" : "no active vm"
            @logger.info('Existing desired instance ' +
                         "'#{instance.job}/#{instance.index}' in az " +
                         "'#{instance_plan.desired_instance.availability_zone}' " +
                         "with #{vm_activeness_msg}"
                        )
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
