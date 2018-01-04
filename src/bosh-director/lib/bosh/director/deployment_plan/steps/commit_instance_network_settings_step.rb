module Bosh::Director
  module DeploymentPlan::Steps
    class CommitInstanceNetworkSettingsStep
      def initialize(ip_provider)
        @ip_provider = ip_provider
      end

      def perform(report)
        report.network_plans.select(&:desired?).each { |network_plan| network_plan.existing = true }

        return if @ip_provider.nil?

        report.network_plans.select(&:obsolete?).each do |network_plan|
          reservation = network_plan.reservation
          @ip_provider.release(reservation)
        end
        report.network_plans.delete_if(&:obsolete?)
      end
    end
  end
end
