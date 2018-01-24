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

          Models::IpAddress.where(address_str: IpUtil::CIDRIP.new(network_plan.reservation.ip).to_s)
                           .update(vm_id: report.vm.id)
        end
      end
    end
  end
end
