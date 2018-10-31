module Bosh::Director
  module DeploymentPlan
    module Stages
      Report = Struct.new(
        :vm,
        :network_plans,
        :disk_hint,
      )
    end
  end
end
