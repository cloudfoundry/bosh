module Bosh::Director
  module DeploymentPlan
    module NetworkPlanner
      class VipPlanner
        include IpUtil
        def initialize(network_planner, logger)
          @network_planner = network_planner
          @logger = logger
        end

        def add_vip_network_plans(instance_plans, vip_networks)
          vip_networks.each do |vip_network|
            static_ips = vip_network.static_ips.nil? ? [] : vip_network.static_ips.dup

            if !static_ips.empty? && vip_network.deployment_network.globally_allocate_ip?
              raise(
                Bosh::Director::NetworkReservationVipMisconfigured,
                'IPs cannot be specified in both the instance group and the cloud config',
              )
            end

            if vip_network.deployment_network.globally_allocate_ip?
              create_global_networks_plans(instance_plans, vip_network)
            else
              create_instance_defined_network_plans(instance_plans, vip_network, static_ips)
            end
          end
        end

        private

        def create_global_networks_plans(instance_plans, vip_network)
          instance_plans.each do |instance_plan|
            instance_plan.network_plans << @network_planner.network_plan_with_dynamic_reservation(instance_plan, vip_network)
          end
        end

        def create_instance_defined_network_plans(instance_plans, vip_network, static_ips)
          unplaced_instance_plans = []

          instance_plans.each do |plan|
            static_ip = get_instance_static_ip(plan.existing_instance, vip_network.name, static_ips)
            if static_ip
              plan.network_plans << @network_planner.network_plan_with_static_reservation(plan, vip_network, static_ip)
            else
              unplaced_instance_plans << plan
            end
          end

          unplaced_instance_plans.each do |plan|
            static_ip = static_ips.shift
            plan.network_plans << @network_planner.network_plan_with_static_reservation(plan, vip_network, static_ip)
          end
        end

        def get_instance_static_ip(existing_instance, network_name, static_ips)
          return unless existing_instance

          existing_instance_ip = find_ip_for_network(existing_instance, network_name)

          return unless existing_instance_ip && ip_in_array?(existing_instance_ip, static_ips)

          static_ips.delete(existing_instance_ip)

          existing_instance_ip
        end

        def find_ip_for_network(existing_instance, network_name)
          ip_address = existing_instance.ip_addresses.find do |ip|
            ip.network_name == network_name
          end

          ip_address&.address
        end
      end
    end
  end
end
