module Bosh::Director::DeploymentPlan
  module NetworkPlanner
    class VipStaticIpsPlanner
      def initialize(network_planner, logger)
        @network_planner = network_planner
        @logger = logger
      end

      def add_vip_network_plans(instance_plans, vip_networks)
        vip_networks.each do |vip_network|
          static_ips = vip_network.static_ips.dup

          unplaced_instance_plans = []
          instance_plans.each do |instance_plan|
            static_ip = get_instance_static_ip(instance_plan.existing_instance, vip_network.name, static_ips)
            if static_ip
              instance_plan.network_plans << @network_planner.network_plan_with_static_reservation(instance_plan, vip_network, static_ip)
            else
              unplaced_instance_plans << instance_plan
            end
          end

          unplaced_instance_plans.each do |instance_plan|
            static_ip = static_ips.shift
            instance_plan.network_plans << @network_planner.network_plan_with_static_reservation(instance_plan, vip_network, static_ip)
          end
        end
      end

      private

      def get_instance_static_ip(existing_instance, network_name, static_ips)
        if existing_instance
          existing_instance_ip = find_ip_for_network(existing_instance, network_name)
          if existing_instance_ip && static_ips.include?(existing_instance_ip)
            static_ips.delete(existing_instance_ip)
            return existing_instance_ip
          end
        end
      end

      def find_ip_for_network(existing_instance, network_name)
        ip_address = existing_instance.ip_addresses.find do |ip_address|
          ip_address.network_name == network_name
        end
        ip_address.address if ip_address
      end
    end
  end
end
