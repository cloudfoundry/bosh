module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class AvailabilityZonePicker
          def initialize(instance_plan_factory, network_planner, networks, desired_azs)
            @instance_plan_factory = instance_plan_factory
            @network_planner = network_planner
            @networks = networks
            @desired_azs = desired_azs
            @logger = Config.logger
          end

          def place_and_match_in(desired_instances, existing_instance_models)
            validate_networks_not_changed_for_ignore_vms(existing_instance_models)

            unplaced_existing_instances =  UnplacedExistingInstances.new(existing_instance_models)
            desired_azs_sorted = unplaced_existing_instances.azs_sorted_by_existing_instance_count_descending(@desired_azs)
            @logger.debug("Desired azs: #{desired_azs_sorted.inspect}")
            validate_desired_azs_contains_all_azs_from_ignored_instances(unplaced_existing_instances, desired_instances)

            placed_instances = PlacedDesiredInstances.new(desired_azs_sorted)

            remaining_desired_instances_minus_ignored = place_instances_that_have_ignore_flag_as_true(desired_azs_sorted, desired_instances, placed_instances, unplaced_existing_instances)
            remaining_desired_instances = place_instances_that_have_persistent_disk_in_existing_az(desired_azs_sorted, remaining_desired_instances_minus_ignored, placed_instances, unplaced_existing_instances)
            balance_across_desired_azs(remaining_desired_instances, placed_instances, unplaced_existing_instances)

            obsolete_instance_plans(unplaced_existing_instances.unclaimed) +
              desired_existing_instance_plans(placed_instances.existing) +
              desired_new_instance_plans(placed_instances.absent)
          end

          private

          def place_instances_that_have_ignore_flag_as_true(desired_azs, desired_instances, placed_instances, unplaced_existing_instances)
            return desired_instances if unplaced_existing_instances.ignored_instances.empty?

            desired_instances = desired_instances.dup
            return desired_instances if desired_azs.nil?
            unplaced_existing_instances.ignored_instances.each do |existing_instance|
              az = desired_azs.find { |az| az.name == existing_instance.availability_zone }
              next if az.nil?
              desired_instance = desired_instances.pop
              unplaced_existing_instances.claim_instance(existing_instance)
              placed_instances.record_placement(az, desired_instance, existing_instance)
            end
            desired_instances
          end

          def validate_desired_azs_contains_all_azs_from_ignored_instances(unplaced_existing_instances, desired_instances)
            return if unplaced_existing_instances.ignored_instances.empty?

            if unplaced_existing_instances.ignored_instances.count > desired_instances.count
              @logger.info("Desired instances count, #{desired_instances.count}, is less than existing ignored instances, #{unplaced_existing_instances.ignored_instances.count}")
              raise DeploymentIgnoredInstancesModification, "Instance Group '#{unplaced_existing_instances.ignored_instances.first.job}' has #{unplaced_existing_instances.ignored_instances.count} ignored instance(s)." +
                  " #{desired_instances.count} instance(s) of that instance group were requested. Deleting ignored instances is not allowed."
            end

            ignore_instances_az_names = unplaced_existing_instances.ignored_instances.map(&:availability_zone).compact.uniq
            desired_az_names = @desired_azs.nil? ? [] : @desired_azs.map(&:name)
            ignore_instances_az_names_attempted_to_be_deleted = ignore_instances_az_names - desired_az_names
            unless ignore_instances_az_names_attempted_to_be_deleted.empty?
              raise DeploymentIgnoredInstancesModification, "Instance Group '#{unplaced_existing_instances.ignored_instances.first.job}' no longer contains AZs " +
                  "#{ignore_instances_az_names_attempted_to_be_deleted} where ignored instance(s) exist."
            end
          end

          def place_instances_that_have_persistent_disk_in_existing_az(desired_azs, desired_instances, placed_instances, unplaced_existing_instances)
            desired_instances = desired_instances.dup
            return desired_instances if desired_azs.nil?
            unplaced_existing_instances.instances_with_persistent_disk.each do |existing_instance|
              break if desired_instances.empty?
              az = desired_azs.find { |az| az.name == existing_instance.availability_zone }
              next if az.nil?
              desired_instance = desired_instances.pop
              unplaced_existing_instances.claim_instance(existing_instance)
              placed_instances.record_placement(az, desired_instance, existing_instance)
            end
            desired_instances
          end

          def balance_across_desired_azs(desired_instances, placed_instances, unplaced_existing_instances)
            desired_instances.each do |desired_instance|
              azs_with_fewest_placed = placed_instances.azs_with_fewest_instances
              @logger.debug("azs with fewest placed: #{azs_with_fewest_placed.inspect}")
              az = unplaced_existing_instances.azs_sorted_by_existing_instance_count_descending(azs_with_fewest_placed).first
              @logger.debug("az: #{az.inspect}")

              existing_instance = unplaced_existing_instances.claim_instance_for_az(az)
              placed_instances.record_placement(az, desired_instance, existing_instance)
            end
          end

          def obsolete_instance_plans(obsolete_instances)
            obsolete_instances.map do |existing_instance|
              @instance_plan_factory.obsolete_instance_plan(existing_instance)
            end
          end

          def desired_existing_instance_plans(desired_existing_instances)
            desired_existing_instances.map do |desired_existing_instance|
              instance_plan = @instance_plan_factory.desired_existing_instance_plan(
                desired_existing_instance[:existing_instance_model],
                desired_existing_instance[:desired_instance]
              )
              populate_network_plans(instance_plan)
              instance_plan
            end
          end

          def desired_new_instance_plans(new_desired_instances)
            new_desired_instances.map do |desired_instance|
              instance_plan = @instance_plan_factory.desired_new_instance_plan(desired_instance)
              populate_network_plans(instance_plan)
              instance_plan
            end
          end

          def populate_network_plans(instance_plan)
            @networks.each do |network|
              instance_plan.network_plans << @network_planner.network_plan_with_dynamic_reservation(instance_plan, network)
            end
          end

          def validate_networks_not_changed_for_ignore_vms(existing_instance_models)
            existing_instance_models.each do |existing_instance_model|
              next if !existing_instance_model.ignore

              desired_networks_names = @networks.map(&:name).uniq.sort
              existing_networks_names = existing_instance_model.ip_addresses.map(&:network_name).uniq.sort

              if desired_networks_names != existing_networks_names
                raise DeploymentIgnoredInstancesModification, "In instance group '#{existing_instance_model.job}', which contains ignored vms,"+
                    ' an attempt was made to modify the networks. This operation is not allowed.'
              end
            end
          end
        end
      end
    end
  end
end
