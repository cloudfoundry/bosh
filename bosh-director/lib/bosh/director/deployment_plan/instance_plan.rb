module Bosh
  module Director
    module DeploymentPlan
      class InstancePlan

        # FIXME: This is pretty sad. But it should go away when we move away from using
        # Instance and just become part of making an InstancePlan
        def self.create_from_deployment_plan_instance(instance)
          # no one currently cares if this DesiredInstance is real, we just want to have one for now
          # so our InstancePlan doesnt think it's obsolete
          desired_instance = DeploymentPlan::DesiredInstance.new(nil, {}, nil)

          obsolete_reservations = instance.take_old_reservations
          desired_reservations = instance.network_reservations
          obsolete_network_plans = obsolete_reservations.map do |reservation|
            NetworkPlan.new(ip: reservation.ip, network: reservation.network, obsolete: true)
          end
          desired_network_plans = desired_reservations.map do |reservation|
            NetworkPlan.new(ip: reservation.ip, network: reservation.network, obsolete: false)
          end

          instance_plan = new(
            existing_instance: instance.model,
            instance: instance,
            desired_instance: desired_instance
          )
          instance_plan.network_plans = desired_network_plans + obsolete_network_plans
          instance_plan
        end

        def initialize(attrs)
          @existing_instance = attrs.fetch(:existing_instance)
          @desired_instance = attrs.fetch(:desired_instance)
          @instance = attrs.fetch(:instance)
        end

        attr_reader :desired_instance, :existing_instance, :instance

        attr_accessor :network_plans

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
