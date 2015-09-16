module Bosh
  module Director
    module DeploymentPlan
      class InstancePlan

        # FIXME: This is pretty sad. But it should go away when we move away from using
        # Instance and just become part of making an InstancePlan
        def self.create_from_deployment_plan_instance(instance, logger)
          # no one currently cares if this DesiredInstance is real, we just want to have one for now
          # so our InstancePlan doesn't think it's obsolete
          desired_instance = DeploymentPlan::DesiredInstance.new(nil, {}, nil)

          network_plans = NetworkPlanner.new(logger)
                            .plan_ips(instance.desired_network_reservations, instance.existing_network_reservations)

          instance_plan = new(
            existing_instance: instance.model,
            instance: instance,
            desired_instance: desired_instance
          )
          instance_plan.network_plans = network_plans
          instance_plan
        end

        def initialize(attrs)
          @existing_instance = attrs.fetch(:existing_instance)
          @desired_instance = attrs.fetch(:desired_instance)
          @instance = attrs.fetch(:instance)
          @network_plans = []
        end

        attr_reader :desired_instance, :existing_instance, :instance

        attr_accessor :network_plans

        def networks_changed?
          desired_plans = network_plans.select(&:desired?)
          obsolete_plans = network_plans.select(&:obsolete?)
          obsolete_plans.any? || desired_plans.any?
        end

        def mark_desired_network_plans_as_existing
          network_plans.select(&:desired?).each { |network_plan| network_plan.existing = true }
        end

        def obsolete?
          desired_instance.nil?
        end

        def new?
          existing_instance.nil?
        end
      end
    end
  end
end
