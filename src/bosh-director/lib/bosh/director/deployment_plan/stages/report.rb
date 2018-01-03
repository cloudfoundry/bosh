module Bosh::Director
  module DeploymentPlan
    module Stages
      Report = Struct.new(
        :vm,
        :network_plans,
      )
    end
  end
end
