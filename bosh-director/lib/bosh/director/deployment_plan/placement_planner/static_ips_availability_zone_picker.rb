module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class StaticIpsAvailabilityZonePicker
          def place_and_match_in(desired_azs, job_networks, desired_instances, existing_instance_az_tuples)
            unplaced_existing_instances =  UnplacedExistingInstances.new(existing_instance_az_tuples)
            placed_instances = PlacedDesiredInstances.new(desired_azs)
            azs_from_static_ips = az_list_from_static_ips(desired_azs, job_networks)

            desired_instances.each do |desired_instance|
              az = azs_from_static_ips.shift
              existing = unplaced_existing_instances.claim_instance_for_az(az)
              placed_instances.record_placement(az, desired_instance, existing)
            end

            {
              desired_new: placed_instances.absent,
              desired_existing: placed_instances.existing,
              obsolete: unplaced_existing_instances.unclaimed_instance_models,
            }
          end

          private

          def az_list_from_static_ips(desired_azs, job_networks)
            static_ips = []
            deployment_networks = []

            job_networks.each do |job_network|
              static_ips += job_network.static_ips if job_network.respond_to?(:static_ips) && job_network.static_ips
              deployment_networks << job_network.deployment_network
            end

            subnets = deployment_networks.map { |network| network.subnets }.flatten

            static_ips_to_az_names = {}
            static_ips.each do |static_ip|
              subnet_for_ip = subnets.find { |subnet| subnet.static_ips.include?(static_ip) }
              unless subnet_for_ip.availability_zone_names.nil?
                zone_name = subnet_for_ip.availability_zone_names.first
                static_ips_to_az_names[static_ip] = zone_name
              end
            end

            static_ips_to_az_names.values.map { |az_name| desired_azs.find { |az| az.name == az_name } }
          end
        end
      end
    end
  end
end
