module Bosh
  module Director
    module DeploymentPlan
      class InstancePlan
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
