module Bosh
  module Director
    module DeploymentPlan
      class AvailabilityZonePicker
        def place_and_match_instances(azs, desired_instances, existing_instances)
          az_to_existing_instances  = az_name_to_existing_instances(existing_instances)
          desired = []
          desired_instances.each_with_index do |desired_instance, index|
            az = choose_az_for(index, azs)
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

        def choose_az_for(index, azs)
          (azs.nil? || azs.empty?) ? nil : azs[index % azs.count]
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
