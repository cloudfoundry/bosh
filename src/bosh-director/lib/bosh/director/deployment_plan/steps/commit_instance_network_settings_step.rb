module Bosh::Director
  module DeploymentPlan::Steps
    class CommitInstanceNetworkSettingsStep
      def perform(report)
        report.network_plans.select(&:desired?).each { |network_plan| network_plan.existing = true }
      end
    end
  end
end
