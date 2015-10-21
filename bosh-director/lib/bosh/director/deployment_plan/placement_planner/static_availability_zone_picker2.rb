module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class StaticAvailabilityZonePicker2
          def place_and_match_in(desired_azs, job_networks, desired_instances, existing_instance_models, job_name)
            placed_instances = PlacedDesiredInstances.new(desired_azs)
            networks_to_static_ips = NetworksToStaticIps.create(job_networks, job_name)
            networks_to_static_ips.validate_azs_are_declared_in_job_and_subnets(desired_azs)
            desired_instances = desired_instances.dup

            instance_plans = []
            instance_plans += place_existing_instance_plans(desired_instances, existing_instance_models, job_networks, networks_to_static_ips, placed_instances, desired_azs)
            instance_plans += place_new_instance_plans(desired_instances, job_networks, networks_to_static_ips, placed_instances, desired_azs)
            instance_plans
          end

          private

          def to_az(az_name, desired_azs)
            desired_azs.to_a.find { |az| az.name == az_name }
          end

          def place_existing_instance_plans(desired_instances, existing_instance_models, job_networks, networks_to_static_ips, placed_instances, desired_azs)
            instance_plans = []
            existing_instance_models.each do |existing_instance_model|
              instance_plan = nil
              job_networks.each do |network|
                next unless network.static?
                instance_ips_on_network = existing_instance_model.ip_addresses.select { |ip_address| network.static_ips.include?(ip_address.address) }
                network_plan = nil
                instance_ips_on_network.each do |instance_ip|
                  ip_address = instance_ip.address
                  # Instance is using IP in static IPs list, we have to use this instance
                  if instance_plan.nil?
                    desired_instance = desired_instances.shift
                    if desired_instance.nil?
                      instance_plan = create_obsolete_instance_plan(existing_instance_model)
                    else
                      instance_plan = create_desired_existing_instance_plan(desired_instance, existing_instance_model)
                      ip_az_names = networks_to_static_ips.find_by_network_and_ip(network, ip_address).az_names
                      if ip_az_names.include?(existing_instance_model.availability_zone)
                        az_name = existing_instance_model.availability_zone
                      else
                        az_name = networks_to_static_ips.find_by_network_and_ip(network, ip_address).az_names.first
                      end
                      az = to_az(az_name, desired_azs)
                      placed_instances.record_placement(az, desired_instance, existing_instance_model)
                    end
                    instance_plans << instance_plan
                  end

                  if network_plan.nil? && instance_plan.desired_instance
                    instance_az_name = instance_plan.desired_instance.az.name
                    ip_az_names = networks_to_static_ips.find_by_network_and_ip(network, ip_address).az_names
                    if ip_az_names.include?(instance_az_name)
                      network_plan = create_network_plan_with_ip(instance_plan, network, ip_address)
                    end
                  end

                  # claim so that other instances not reusing ips of existing instance
                  networks_to_static_ips.claim(ip_address)
                end
                instance_plan.network_plans << network_plan if network_plan
              end
            end

            existing_instance_models.each do |existing_instance_model|
              unless instance_plans.map(&:existing_instance).include?(existing_instance_model)
                desired_instance = desired_instances.shift
                if desired_instance.nil?
                  instance_plan = create_obsolete_instance_plan(existing_instance_model)
                else
                  instance_plan = create_desired_existing_instance_plan(desired_instance, existing_instance_model)
                end
                instance_plans << instance_plan
              end
            end

            instance_plans.reject(&:obsolete?).each do |instance_plan|
              job_networks.each do |network|
                if network.static?
                  unless instance_plan.network_plan_for_network(network.deployment_network)
                    static_ip_with_azs = networks_to_static_ips.take_next_ip_for_network(network)
                    unless static_ip_with_azs
                      raise Bosh::Director::NetworkReservationError,
                        'Failed to distribute static IPs to satisfy existing instance reservations'
                    end

                    instance_plan.network_plans << create_network_plan_with_ip(instance_plan, network, static_ip_with_azs.ip)
                    az_name = static_ip_with_azs.az_names.first
                    az = to_az(az_name, desired_azs)
                    placed_instances.record_placement(az, instance_plan.desired_instance, instance_plan.existing_instance)
                  end
                else
                  instance_plan.network_plans << create_dynamic_network_plan(instance_plan, network)
                end
              end
            end

            instance_plans
          end

          def place_new_instance_plans(desired_instances, job_networks, networks_to_static_ips, placed_instances, desired_azs)
            instance_plans = []
            networks_to_static_ips.distribute_evenly_per_zone

            desired_instances.each do |desired_instance|
              instance_plan = create_new_instance_plan(desired_instance)
              az_name = nil

              job_networks.each do |network|
                if network.static?
                  if az_name.nil?
                    static_ip_to_azs = networks_to_static_ips.take_next_ip_for_network(network)
                    az_name = static_ip_to_azs.az_names.first
                  else
                    static_ip_to_azs = networks_to_static_ips.take_next_ip_for_network_and_az(network, az_name)
                  end

                  instance_plan.network_plans << create_network_plan_with_ip(instance_plan, network, static_ip_to_azs.ip)
                else
                  instance_plan.network_plans << create_dynamic_network_plan(instance_plan, network)
                end
              end

              az = to_az(az_name, desired_azs)
              placed_instances.record_placement(az, desired_instance, nil)
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

          def create_obsolete_instance_plan(existing_instance_model)
            InstancePlan.new(
              desired_instance: nil,
              existing_instance: existing_instance_model,
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

          def create_dynamic_network_plan(instance_plan, job_network)
            reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_plan.instance, job_network.deployment_network)
            NetworkPlanner::Plan.new(reservation: reservation)
          end
        end
      end
    end
  end
end
