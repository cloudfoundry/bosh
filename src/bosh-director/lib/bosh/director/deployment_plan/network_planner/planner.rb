module Bosh::Director::DeploymentPlan
  module NetworkPlanner
    class Planner
      def initialize(logger)
        @logger = logger
      end

      def network_plan_with_dynamic_reservation(instance_plan, job_network)
        reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_plan.instance.model, job_network.deployment_network, job_network.nic_group)
        @logger.debug("Creating new dynamic reservation #{reservation} for instance '#{instance_plan.instance}'")
        Plan.new(reservation: reservation)
      end

      def network_plan_with_static_reservation(instance_plan, job_network, static_ip)
        reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_plan.instance.model, job_network.deployment_network, static_ip, job_network.nic_group)
        @logger.debug("Creating new static reservation #{reservation} for instance '#{instance_plan.instance}'")
        Plan.new(reservation: reservation)
      end
    end
  end
end
