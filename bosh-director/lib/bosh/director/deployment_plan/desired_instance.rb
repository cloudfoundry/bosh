module Bosh
  module Director
    module DeploymentPlan
      class DesiredInstance < Struct.new(:job, :state, :deployment, :az, :instance)
      end
    end
  end
end
