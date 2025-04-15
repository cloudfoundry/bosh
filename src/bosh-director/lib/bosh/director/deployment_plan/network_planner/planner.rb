module Bosh::Director::DeploymentPlan
  module NetworkPlanner
    class Planner
      def initialize(logger)
        @logger = logger
      end

      def network_plan_with_dynamic_reservation(instance_plan, job_network)
        plans = []
        reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_plan.instance.model, job_network.deployment_network)
        @logger.debug("Creating new dynamic reservation #{reservation} for instance '#{instance_plan.instance}'")
        plans << Plan.new(reservation: reservation)
        job_network.deployment_network.subnets.each do |subnet|
          unless subnet.prefix.nil?
            prefix_reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_plan.instance.model, job_network.deployment_network, true)
            plans << Plan.new(reservation: prefix_reservation)
          end
        end
        plans
      end

      def network_plan_with_static_reservation(instance_plan, job_network, static_ip)
        plans = []
        reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_plan.instance.model, job_network.deployment_network, static_ip)
        @logger.debug("Creating new static reservation #{reservation} for instance '#{instance_plan.instance}'")
        plans << Plan.new(reservation: reservation)
        job_network.deployment_network.subnets.each do |subnet|
          unless subnet.prefix.nil?
            prefix_reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_plan.instance.model, job_network.deployment_network, true)
            plans << Plan.new(reservation: prefix_reservation)
          end
        end
        plans
      end
    end
  end
end
