module Bosh::Director
  module DeploymentPlan::Steps
    class ReleaseObsoleteNetworksStep
      def initialize(ip_provider)
        @ip_provider = ip_provider
      end

      def perform(report)
        report.network_plans.select(&:obsolete?).each do |network_plan|
          reservation = network_plan.reservation
          @ip_provider.release(reservation)
        end
        report.network_plans.delete_if(&:obsolete?)
      end
    end
  end
end
