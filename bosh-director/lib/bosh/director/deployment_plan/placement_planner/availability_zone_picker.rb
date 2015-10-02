module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class AvailabilityZonePicker
          def place_and_match_in(desired_azs, desired_instances, existing_instances_with_azs)
            unplaced_existing_instances =  UnplacedExistingInstances.new(existing_instances_with_azs)
            desired_azs = unplaced_existing_instances.azs_sorted_by_existing_instance_count_descending(desired_azs)
            placed_instances = PlacedDesiredInstances.new(desired_azs)

            remaining_desired_instances = place_instances_that_have_persistent_disk_in_existing_az(desired_azs, desired_instances, placed_instances, unplaced_existing_instances)
            balance_across_desired_azs(remaining_desired_instances, placed_instances, unplaced_existing_instances)

            obsolete = unplaced_existing_instances.unclaimed_instance_models

            # TODO:
            # - Consider making this a AvailabilityZonePlacementPlan class
            # - Consider moving index assignment into the PlacementPlan class
            zoned_instances = {
              desired_new: placed_instances.absent,
              desired_existing: placed_instances.existing,
              obsolete: obsolete,
            }

            # TODO: move this call to PlacementPlanner::Plan
            IndexAssigner.new.assign_indexes(zoned_instances)
            zoned_instances
          end

          private

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
              az = unplaced_existing_instances.azs_sorted_by_existing_instance_count_descending(azs_with_fewest_placed).first
              existing_instance = unplaced_existing_instances.claim_instance_for_az(az)
              placed_instances.record_placement(az, desired_instance, existing_instance)
            end
          end
        end
      end
    end
  end
end
