module Bosh
  module Director
    module DeploymentPlan
      class AvailabilityZonePicker
        def place_and_match_instances(azs, desired_instances, existing_instances)
          existing_instances = existing_instances.sort_by { |instance| instance.index}
          az_to_existing_instances  = az_name_to_existing_instances(existing_instances)

          azs = azs_sorted_by_existing_instance_count_descending(azs, az_to_existing_instances)

          desired = []
          desired_instances.each_with_index do |desired_instance, i|
            az = choose_az_for(i, azs)
            desired_instance.az = az
            desired_instance.instance = existing_instance_for_az(az, az_to_existing_instances)
            desired << desired_instance
          end

          {
            desired: desired,
            obsolete: az_to_existing_instances.values.flatten
          }
        end

        private

        def choose_az_for(i, azs)
          (azs.nil? || azs.empty?) ? nil : azs[i % azs.count]
        end

        def azs_sorted_by_existing_instance_count_descending(azs, az_names_to_existing_instances)
          return nil if azs.nil?
          azs.sort_by { |az| - az_names_to_existing_instances.fetch(az.name, []).size }
        end

        def az_name_to_existing_instances(existing_instances)
          az_to_existing_instances = {}
          existing_instances.each do |instance|
            az_name = instance.availability_zone
            if az_to_existing_instances[az_name].nil?
              az_to_existing_instances[az_name] = [instance]
            else
              az_to_existing_instances[az_name] << instance
            end
          end
          az_to_existing_instances
        end

        def existing_instance_for_az(az, az_to_existing_instances)
          az_name = az.nil? ? nil : az.name
          instances = az_to_existing_instances[az_name]
          unless instances.nil? || instances.empty?
            instances.shift
          end
        end
      end
    end
  end
end
