module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class Plan
          def initialize(instance_plan_factory, network_planner, logger)
            @instance_plan_factory = instance_plan_factory
            @network_planner = network_planner
            @logger = logger
          end

          def create_instance_plans(desired, existing, networks, availability_zones, job_name)
            sorted_existing = existing.sort_by(&:index)
            instance_plans = assign_zones(desired, sorted_existing, networks, availability_zones, job_name)

            instance_plans.reject(&:obsolete?).each do |instance_plan|
              @logger.debug("Assigning az '#{instance_plan.desired_instance.availability_zone}' to instance '#{instance_plan.instance}'")
              instance_plan.instance.assign_availability_zone_and_update_cloud_properties(instance_plan.desired_instance.az, instance_plan.desired_instance.instance_group.vm_type, instance_plan.desired_instance.instance_group.vm_extensions)
            end
            instance_plans
          end

          private

          def assign_zones(desired, existing, networks, availability_zones, job_name)
            if has_static_ips?(networks)
              @logger.debug("Job '#{job_name}' has networks with static IPs, placing instances based on static IP distribution")
              StaticIpsAvailabilityZonePicker.new(@instance_plan_factory, @network_planner, networks, job_name, availability_zones, @logger).place_and_match_in(desired, existing)
            else
              @logger.debug("Job '#{job_name}' does not have networks with static IPs, placing instances based on persistent disk allocation")
              AvailabilityZonePicker.new(@instance_plan_factory, @network_planner, networks, availability_zones).place_and_match_in(desired, existing)
            end
          end

          def has_static_ips?(networks)
            !networks.nil? && networks.any? { |network| !! network.static_ips }
          end
        end
      end
    end
  end
end
