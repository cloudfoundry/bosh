module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class Plan
          def initialize(instance_plan_factory, logger)
            @instance_plan_factory = instance_plan_factory
            @logger = logger
          end

          def create_instance_plans(desired, existing, networks, availability_zones, job_name)
            instance_plans = assign_zones(desired, existing, networks, availability_zones, job_name)

            instance_plans.reject(&:obsolete?).each do |instance_plan|
              @logger.debug("Assigning az '#{instance_plan.desired_instance.availability_zone}' to instance '#{instance_plan.instance}'")
              instance_plan.instance.assign_availability_zone(instance_plan.desired_instance.az)
            end
            instance_plans
          end

          private

          def assign_zones(desired, existing, networks, availability_zones, job_name)
            if has_static_ips?(networks)
              @logger.debug("Job '#{job_name}' has networks with static IPs, placing instances based on static IP distribution")
              StaticIpsAvailabilityZonePicker.new(@instance_plan_factory).place_and_match_in(availability_zones, networks, desired, existing, job_name)
            else
              @logger.debug("Job '#{job_name}' does not have networks with static IPs, placing instances based on persistent disk allocation")
              AvailabilityZonePicker.new(@instance_plan_factory).place_and_match_in(availability_zones, desired, existing)
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
