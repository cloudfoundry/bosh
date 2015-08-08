module Bosh
  module Director
    module DeploymentPlan
      class DesiredInstance < Struct.new(:job, :state, :deployment)
      end
    end
  end
end
