module Bosh
  module Director
    module DeploymentPlan
      class DesiredInstance < Struct.new(:job, :state, :deployment, :az, :existing_instance, :index, :bootstrap)

        def inspect
          "#{self.az.name}/#{self.index}"
        end

        def bootstrap?
          self.bootstrap
        end

        def mark_as_bootstrap
          self.bootstrap = true
        end
      end
    end
  end
end
