module Bosh
  module Director
    module DeploymentPlan
      class AvailabilityZonePicker
        def place_and_match_instances(azs, desired_instances, existing_instances)
          existing_instances = existing_instances.sort_by { |instance| instance.index}
          az_name_to_existing_instances  = az_name_to_existing_instances(existing_instances)
          azs = azs_sorted_by_existing_instance_count_descending(azs, az_name_to_existing_instances)

          placed_instances = PlacedInstances.new(azs)

          unplaced_existing_instances =  UnplacedExistingInstances.new(existing_instances)

          unplaced_existing_instances.instances_with_persistent_disk.each do |existing_instance|
            az = azs.find {|az| az.name == existing_instance.availability_zone}
            next if az.nil?
            desired_instance = desired_instances.pop
            az_name_to_existing_instances[az.name].delete(existing_instance)
            desired_instance.az = az
            desired_instance.existing_instance = existing_instance
            placed_instances.record_placement(az, desired_instance)
          end

          desired_instances.each do |desired_instance|
            azs_with_fewest_placed = placed_instances.azs_with_fewest_instances
            az = azs_sorted_by_existing_instance_count_descending(azs_with_fewest_placed, az_name_to_existing_instances).first
            desired_instance.az = az
            desired_instance.existing_instance = existing_instance_for_az(az, az_name_to_existing_instances)
            placed_instances.record_placement(az, desired_instance)
          end

          obsolete = az_name_to_existing_instances.values.flatten
          assign_indexes(placed_instances.desired_existing, placed_instances.desired_new, obsolete)

          {
            desired_new: placed_instances.desired_new,
            desired_existing: placed_instances.desired_existing,
            obsolete: obsolete,
          }
        end

        private

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

        class UnplacedExistingInstances
          def initialize(existing_instance_models)
            @instance_models = existing_instance_models
          end

          def instances_with_persistent_disk
            @instance_models.select do |instance_model|
              instance_model.persistent_disks && instance_model.persistent_disks.count > 0
            end
          end
        end

        class PlacedInstances
          attr_reader :desired_new, :desired_existing, :obsolete

          def initialize(azs)
            @placed = {}
            azs.each do |az|
              @placed[az] = []
            end

            @desired_new = []
            @desired_existing = []
            @obsolete = []
          end

          def record_placement(az, desired_instance)
            az_desired_instances = @placed.fetch(az, [])
            az_desired_instances << desired_instance
            @placed[az] = az_desired_instances
            if desired_instance.existing_instance.nil?
              desired_new << desired_instance
            else
              desired_existing << desired_instance
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
