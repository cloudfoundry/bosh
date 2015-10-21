module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class StaticAvailabilityZonePicker2
          def place_and_match_in(desired_azs, job_networks, desired_instances, existing_instance_models, job_name)
            placed_instances = PlacedDesiredInstances.new(desired_azs)
            networks_to_static_ips = NetworksToStaticIps.create(job_networks, job_name)
            desired_instances = desired_instances.dup

            instance_plans = []
            existing_instance_models.each do |existing_instance_model|
              instance_plan = nil
              job_networks.each do |network|
                instance_ips_on_network = existing_instance_model.ip_addresses.select { |ip_address| network.static_ips.include?(ip_address.address) }
                network_plan = nil
                instance_ips_on_network.each do |instance_ip|
                  ip_address = instance_ip.address
                  # Instance is using IP in static IPs list, we have to use this instance
                  if instance_plan.nil?
                    desired_instance = desired_instances.shift
                    if desired_instance.nil?
                      # TODO: fail, there are more static IPs on existing instances than desired instances
                    end
                    instance_plan = create_desired_existing_instance_plan(desired_instance, existing_instance_model)
                    az_name = networks_to_static_ips.find_by_network_and_ip(network, ip_address).az_names.first
                    az = to_az(az_name, desired_azs)
                    placed_instances.record_placement(az, desired_instance, existing_instance_model)
                  end

                  if network_plan.nil?
                    network_plan = create_network_plan_with_ip(instance_plan, network, ip_address)
                  end

                  # claim so that other instances not reusing ips of existing instance
                  networks_to_static_ips.claim(ip_address)
                end
                instance_plan.network_plans << network_plan if network_plan
              end

              if instance_plan.nil?
                desired_instance = desired_instances.shift
                if desired_instance.nil?
                  # TODO: mark as obsolete
                else
                  instance_plan = create_desired_existing_instance_plan(desired_instance, existing_instance_model)
                end
              end

              instance_plans << instance_plan
            end

            instance_plans.each do |instance_plan|
              job_networks.each do |network|
                unless instance_plan.network_plan_for_network(network.deployment_network)
                  static_ip_with_azs = networks_to_static_ips.take_next_ip_for_network(network)
                  unless static_ip_with_azs
                    # TODO: fail, cannot fulfill network plan
                  end

                  instance_plan.network_plans << create_network_plan_with_ip(instance_plan, network, static_ip_with_azs.ip)
                  az_name = static_ip_with_azs.az_names.first
                  az = to_az(az_name, desired_azs)
                  placed_instances.record_placement(az, instance_plan.desired_instance, instance_plan.existing_instance)
                end
              end
            end


            instance_plans += place_new_instance_plans(desired_instances, job_networks, networks_to_static_ips, placed_instances, desired_azs)
            instance_plans
          end

          private

          def to_az(az_name, desired_azs)
            desired_azs.to_a.find { |az| az.name == az_name }
          end

          def place_new_instance_plans(desired_instances, job_networks, networks_to_static_ips, placed_instances, desired_azs)
            instance_plans = []
            networks_to_static_ips.distribute_evenly_per_zone

            desired_instances.each do |desired_instance|
              instance_plan = create_new_instance_plan(desired_instance)
              network_plans = []
              az_name = nil

              job_networks.each do |network|
                if az_name.nil?
                  static_ip_to_azs = networks_to_static_ips.take_next_ip_for_network(network)
                  az_name = static_ip_to_azs.az_names.first
                else
                  static_ip_to_azs = networks_to_static_ips.take_next_ip_for_network_and_az(network, az_name)
                end

                network_plans << create_network_plan_with_ip(instance_plan, network, static_ip_to_azs.ip)
              end

              az = to_az(az_name, desired_azs)
              placed_instances.record_placement(az, desired_instance, nil)

              instance_plan.network_plans = network_plans
              instance_plans << instance_plan
            end
            instance_plans
          end

          def create_new_instance_plan(desired_instance)
            InstancePlan.new(
              desired_instance: desired_instance,
              existing_instance: nil,
              instance: nil
            )
          end

          def create_desired_existing_instance_plan(desired_instance, existing_instance_model)
            InstancePlan.new(
              desired_instance: desired_instance,
              existing_instance: existing_instance_model,
              instance: nil
            )
          end

          def create_network_plan_with_ip(instance_plan, job_network, static_ip)
            reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_plan.instance, job_network.deployment_network, static_ip)
            NetworkPlanner::Plan.new(reservation: reservation)
          end
        end
      end
    end
  end
end
