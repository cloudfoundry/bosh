module Bosh
  module Director
    module DeploymentPlan
      class AvailabilityZonePicker
        def place_and_match_instances(azs, desired_instances, existing_instances)
          existing_instances = existing_instances.sort_by { |instance| instance.index}
          az_name_to_existing_instances  = az_name_to_existing_instances(existing_instances)
          azs = azs_sorted_by_existing_instance_count_descending(azs, az_name_to_existing_instances)
          placed_instances = PlacedInstances.new(azs)

          desired_existing_with_persistent_disks = place_with_persistent_disks(desired_instances, azs, existing_instances, az_name_to_existing_instances, placed_instances)
          desired_existing_without_persistent_disks, desired_new = place_remaining(desired_instances, az_name_to_existing_instances, placed_instances)

          desired_existing = desired_existing_with_persistent_disks + desired_existing_without_persistent_disks
          obsolete = az_name_to_existing_instances.values.flatten

          assign_indexes(desired_existing, desired_new, obsolete)

          {
            desired_new: desired_new,
            desired_existing: desired_existing,
            obsolete: obsolete,
          }
        end

        private

        def place_with_persistent_disks(desired_instances, azs, existing_instances, az_name_to_existing_instances, placed_instances)
          desired_existing = []

          az_name_to_az_object = {}
          azs.each do |az|
            az_name_to_az_object[az.name] = az
          end

          existing_instances.each do |existing_instance|
            if existing_instance.persistent_disks && existing_instance.persistent_disks.count > 0
              az = az_name_to_az_object[existing_instance.availability_zone]
              next if az.nil?
              desired_instance = desired_instances.pop
              az_name_to_existing_instances[az.name].delete(existing_instance)
              desired_instance.az = az
              desired_instance.existing_instance = existing_instance
              desired_existing << desired_instance

              placed_instances.place_in(az, desired_instance)
            end
          end

          return desired_existing
        end

        def place_remaining(desired_instances, az_name_to_existing_instances, placed_instances)
          desired_new = []
          desired_existing = []

          desired_instances.each do |desired_instance|
            az = az_with_least_number_of_instances(placed_instances, az_name_to_existing_instances)

            placed_instances.place_in(az, desired_instance)

            desired_instance.az = az
            instance = existing_instance_for_az(az, az_name_to_existing_instances)
            desired_instance.existing_instance = instance
            if instance.nil?
              desired_new << desired_instance
            else
              desired_existing << desired_instance
            end
          end
          return desired_existing, desired_new
        end

        def az_with_least_number_of_instances(placed_instances, az_name_to_existing_instances)
          azs_sorted_by_existing_instance_count_descending(placed_instances.next_possible_azs(), az_name_to_existing_instances).first
        end

        def assign_indexes(desired_existing, desired_new, obsolete)
          count = desired_new.count + desired_existing.count + obsolete.count
          candidate_indexes = (0..count).to_a

          obsolete.each do |instance_model|
            candidate_indexes.delete(instance_model.index)
          end
          desired_existing.each do |desired_instance|
            candidate_indexes.delete(desired_instance.existing_instance.index)
          end
          desired_new.each do |desired_instance|
            desired_instance.index = candidate_indexes.shift
          end
        end

        def choose_az_for(i, azs)
          (azs.nil? || azs.empty?) ? nil : azs[i % azs.count]
        end

        def azs_sorted_by_existing_instance_count_descending(azs, az_names_to_existing_instances)
          return nil if azs.nil?
          azs.sort_by { |az| - az_names_to_existing_instances.fetch(az.name, []).size }
        end

        def az_name_to_existing_instances(existing_instances)
          az_name_to_existing_instances = {}
          existing_instances.each do |instance|
            az_name = instance.availability_zone
            if az_name_to_existing_instances[az_name].nil?
              az_name_to_existing_instances[az_name] = [instance]
            else
              az_name_to_existing_instances[az_name] << instance
            end
          end
          az_name_to_existing_instances
        end

        def existing_instance_for_az(az, az_name_to_existing_instances)
          az_name = az.nil? ? nil : az.name
          instances = az_name_to_existing_instances[az_name]
          unless instances.nil? || instances.empty?
            instances.shift
          end
        end


        class PlacedInstances
          def initialize(azs)
            @placed = {}
            azs.each do |az|
              @placed[az] = []
            end
          end

          def place_in(az, desired_instance)
            az_desired_instances = @placed.fetch(az, [])
            az_desired_instances << desired_instance
            @placed[az] = az_desired_instances
          end

          def next_possible_azs()
            az_with_fewest = @placed.keys.min_by { |az|@placed[az].size }
            @placed.keys.select { |az| (@placed[az].size == @placed[az_with_fewest].size) && az }
          end
        end
      end
    end
  end
end
