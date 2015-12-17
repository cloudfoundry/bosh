module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class UnplacedExistingInstances
          def initialize(existing_instance_models)
            @instances = existing_instance_models.sort_by { |instance_model| instance_model.index }
            @az_name_to_existing_instances  = initialize_azs_to_instances
          end

          def instances_with_persistent_disk
            @instances.select do |instance_model|
              instance_model.persistent_disks && instance_model.persistent_disks.count > 0
            end
          end

          def azs_sorted_by_existing_instance_count_descending(azs)
            return nil if azs.nil?
            azs.sort_by { |az| - @az_name_to_existing_instances.fetch(az.name, []).size }
          end

          def claim_instance(existing_instance)
            @az_name_to_existing_instances[existing_instance.availability_zone].delete(existing_instance)
          end

          def claim_instance_for_az(az)
            az_name = az.nil? ? nil : az.name
            instances = @az_name_to_existing_instances[az_name]
            unless instances.nil? || instances.empty?
              instances.shift
            end
          end

          def unclaimed
            @az_name_to_existing_instances.values.flatten
          end

          private

          def initialize_azs_to_instances
            az_name_to_existing_instances = {}
            @instances.each do |instance|
              instances = az_name_to_existing_instances.fetch(instance.availability_zone, [])
              instances << instance
              az_name_to_existing_instances[instance.availability_zone] = instances
            end
            az_name_to_existing_instances
          end
        end
      end
    end
  end
end
