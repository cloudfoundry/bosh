module Bosh
  module Director
    module DeploymentPlan
      class DesiredInstance < Struct.new(:job, :state, :deployment, :az, :existing_instance, :index)
      end
    end
  end
end
