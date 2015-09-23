module Bosh
  module Director
    module DeploymentPlan
      class AvailabilityZonePicker
        def place_and_match_in(desired_azs, desired_instances, existing_instances_with_azs)
          unplaced_existing_instances =  UnplacedExistingInstances.new(existing_instances_with_azs)
          desired_azs = unplaced_existing_instances.azs_sorted_by_existing_instance_count_descending(desired_azs)
          placed_instances = PlacedDesiredInstances.new(desired_azs)

          remaining_desired_instances = place_instances_that_have_persistent_disk_in_existing_az(desired_azs, desired_instances, placed_instances, unplaced_existing_instances)
          balance_across_desired_azs(remaining_desired_instances, placed_instances, unplaced_existing_instances)

          obsolete = unplaced_existing_instances.unclaimed_instance_models
          assign_indexes(placed_instances.existing, placed_instances.new, obsolete)

          {
            desired_new: placed_instances.new,
            desired_existing: placed_instances.existing,
            obsolete: obsolete,
          }
        end

        private

        def place_instances_that_have_persistent_disk_in_existing_az(desired_azs, desired_instances, placed_instances, unplaced_existing_instances)
          desired_instances = desired_instances.dup
          return desired_instances if desired_azs.nil?
          unplaced_existing_instances.instances_with_persistent_disk.each do |existing_instance|
            break if desired_instances.empty?
            az = desired_azs.find { |az| az.name == existing_instance.az }
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

        def assign_indexes(desired_existing, desired_new, obsolete)
          count = desired_new.count + desired_existing.count + obsolete.count
          candidate_indexes = (0..count).to_a

          obsolete.each do |instance_model|
            candidate_indexes.delete(instance_model.index)
          end

          desired_existing
            .map {|instance_and_deployment| instance_and_deployment[:instance] }
            .each { |existing_instance| candidate_indexes.delete(existing_instance.index) }

          desired_new.each do |desired_instance|
            desired_instance.index = candidate_indexes.shift
          end
        end

        class UnplacedExistingInstances
          def initialize(existing_instances_with_azs)
            @instances = existing_instances_with_azs.sort_by { |instance| instance.model.index }
            @az_name_to_existing_instances  = initialize_azs_to_instances
          end

          def instances_with_persistent_disk
            @instances.select do |instance|
              instance.model.persistent_disks && instance.model.persistent_disks.count > 0
            end
          end

          def azs_sorted_by_existing_instance_count_descending(azs)
            return nil if azs.nil?
            azs.sort_by { |az| - @az_name_to_existing_instances.fetch(az.name, []).size }
          end

          def claim_instance(existing_instance)
            @az_name_to_existing_instances[existing_instance.az].delete(existing_instance)
          end

          def claim_instance_for_az(az)
            az_name = az.nil? ? nil : az.name
            instances = @az_name_to_existing_instances[az_name]
            unless instances.nil? || instances.empty?
              instances.shift
            end
          end

          def unclaimed_instance_models
            @az_name_to_existing_instances.values.flatten.map(&:model)
          end

          private

          def initialize_azs_to_instances
            az_name_to_existing_instances = {}
            @instances.each do |instance|
              instances = az_name_to_existing_instances.fetch(instance.az, [])
              instances << instance
              az_name_to_existing_instances[instance.az] = instances
            end
            az_name_to_existing_instances
          end
        end

        class PlacedDesiredInstances
          attr_reader :new, :existing
          def initialize(azs)
            @placed = {}
            (azs || []).each do |az|
              @placed[az] = []
            end

            @new = []
            @existing = []
          end

          def record_placement(az, desired_instance, existing_instance)
            desired_instance.az = az
            desired_instance.is_existing = existing_instance ? !existing_instance.model.nil? : false
            az_desired_instances = @placed.fetch(az, [])
            az_desired_instances << desired_instance
            @placed[az] = az_desired_instances
            if desired_instance.is_existing
              diffed_instance = existing_instance.model
              diffed_instance.state = desired_instance.state unless desired_instance.state.nil?
              diffed_instance.job = desired_instance.job.name
              diffed_instance.availability_zone = desired_instance.az.name unless desired_instance.az.nil?
              existing << { instance: diffed_instance, deployment: desired_instance.deployment }
            else
              new << desired_instance
            end
          end

          def azs_with_fewest_instances
            az_with_fewest = @placed.keys.min_by { |az|@placed[az].size }
            @placed.keys.select { |az| (@placed[az].size == @placed[az_with_fewest].size) && az }
          end
        end
      end
    end
  end
end
