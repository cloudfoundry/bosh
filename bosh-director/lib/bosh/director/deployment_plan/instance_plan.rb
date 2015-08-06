module Bosh
  module Director
    module DeploymentPlan
      class InstancePlan
        def initialize(attrs)
          @existing_instance = attrs.fetch(:existing_instance)
          @instance = attrs.fetch(:instance)
          @obsolete = attrs.fetch(:obsolete, false)
        end

        attr_reader :instance, :existing_instance

        def obsolete?
          @obsolete
        end

        def new?
          existing_instance.nil?
        end
      end
    end
  end
end
