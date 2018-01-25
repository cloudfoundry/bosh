module Bosh::Director
  module DeploymentPlan
    module Stages
      Agenda = Struct.new(
        :report,
        :thread_name,
        :task_name,
        :info,
        :steps,
      )
    end
  end
end
