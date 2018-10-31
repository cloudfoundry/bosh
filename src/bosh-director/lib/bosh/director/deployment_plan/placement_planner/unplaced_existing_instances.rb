module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class UnplacedExistingInstances
          def initialize(existing_instance_models)
            instances = existing_instance_models.sort_by(&:index)
            @az_name_to_existing_instances = initialize_azs_to_instances(instances)
          end

          def instances_with_persistent_disk
            @az_name_to_existing_instances.values.flatten.select do |instance_model|
              instance_model.persistent_disks&.count&.positive?
            end.sort_by(&:index)
          end

          def ignored_instances
            @az_name_to_existing_instances.values.flatten.select(&:ignore).sort_by(&:index)
          end

          def azs_sorted_by_existing_instance_count_descending(azs)
            return nil if azs.nil?
            azs.sort_by { |az| - @az_name_to_existing_instances.fetch(az.name, []).size }
          end

          def claim_instance(existing_instance)
            @az_name_to_existing_instances[existing_instance.availability_zone].delete(existing_instance)
          end

          def claim_instance_for_az(availability_zone)
            az_name = availability_zone.nil? ? nil : availability_zone.name
            instances = @az_name_to_existing_instances[az_name]
            instances.shift unless instances.nil? || instances.empty?
          end

          def unclaimed
            @az_name_to_existing_instances.values.flatten
          end

          def azs
            unclaimed.map(&:availability_zone).compact
          end

          private

          def initialize_azs_to_instances(existing_instances)
            az_name_to_existing_instances = {}
            existing_instances.each do |instance|
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
