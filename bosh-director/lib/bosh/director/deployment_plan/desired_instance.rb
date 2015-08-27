module Bosh
  module Director
    module DeploymentPlan
      class DesiredInstance < Struct.new(:job, :state, :deployment, :az, :existing_instance, :index)

        def inspect
          "#{az.name}/#{index}"
        end

      end
    end
  end
end
