module Bosh
  module Director
    module DeploymentPlan
      class InstancePlan

        def self.create_from_deployment_plan_instance(instance)
          #FIXME: This is the worst
          desired_instance = DeploymentPlan::DesiredInstance.new(
            nil,# TODO: do we need a real job?
            {}, # TODO: do we need real state here?
            nil,# TODO: do we need a real deployment?
          )

          #TODO: network_plans

          new(
            existing_instance: instance.model,
            instance: instance,
            desired_instance: desired_instance
          )
        end

        def initialize(attrs)
          @existing_instance = attrs.fetch(:existing_instance)
          @desired_instance = attrs.fetch(:desired_instance)
          @instance = attrs.fetch(:instance)
        end

        attr_reader :desired_instance, :existing_instance, :instance

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
