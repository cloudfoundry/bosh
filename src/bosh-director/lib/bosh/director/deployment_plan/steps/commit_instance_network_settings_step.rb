module Bosh::Director
  module DeploymentPlan::Steps
    class CommitInstanceNetworkSettingsStep
      def perform(report)
        report.network_plans.select(&:desired?).each do |network_plan|
          network_plan.existing = true
        end

        report.network_plans.select(&:existing?).each do |network_plan|
          ip = network_plan.reservation.ip

          next if ip.nil?

          ip_model = Models::IpAddress.find(address_str: ip.to_s)
          ip_model&.update(vm: report.vm)
        end
      end
    end
  end
end
