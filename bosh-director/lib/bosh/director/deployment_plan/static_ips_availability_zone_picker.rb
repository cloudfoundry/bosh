module Bosh
  module Director
    module DeploymentPlan
      class StaticIpsAvailabilityZonePicker

        def place_and_match_in(desired_azs, job_networks, desired_instances, existing_instances_with_azs)
          placed_instances = AvailabilityZonePicker::PlacedDesiredInstances.new(desired_azs)

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
              zone_name = subnet_for_ip.availability_zone_names.first # first ???
              static_ips_to_az_names[static_ip] = zone_name
            end
          end

          static_ip_azs = static_ips_to_az_names.values.map{|az_name| desired_azs.find {|az| az.name == az_name}}

          desired_instances.each do |desired_instance|
            placed_instances.record_placement(static_ip_azs.shift, desired_instance, nil)
          end

          placement_plan = {
            desired_new: placed_instances.absent,
            desired_existing: placed_instances.existing, # note this will always be []
            obsolete: [],
          }

          AvailabilityZonePicker::IndexAssigner.new.assign_indexes(placement_plan)
          placement_plan
        end

        private

      end
    end
  end
end
