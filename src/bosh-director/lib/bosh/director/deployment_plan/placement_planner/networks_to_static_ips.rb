module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class NetworksToStaticIps
          extend Bosh::Director::IpUtil
          include Bosh::Director::IpUtil

          def self.create(job_networks, desired_azs, job_name)
            networks_to_static_ips = {}

            desired_az_names = desired_azs.nil? ? [nil] : desired_azs.to_a.map(&:name)

            job_networks.each do |job_network|
              next unless job_network.static?
              subnets = job_network.deployment_network.subnets

              job_network.static_ips.each do |static_ip|
                subnet_for_ip = subnets.find { |subnet| ip_in_array?(static_ip, subnet.static_ips) }
                if subnet_for_ip.nil?
                  raise InstanceGroupNetworkInstanceIpMismatch,
                    "Instance group '#{job_name}' with network '#{job_network.name}' declares static ip '#{base_addr(static_ip)}', " +
                      "which belongs to no subnet"
                end
                az_names = subnet_for_ip.availability_zone_names.nil? ? [nil] : subnet_for_ip.availability_zone_names
                filtered_az_names = az_names.select { |static_ip_az_name| desired_az_names.include?(static_ip_az_name) }.uniq
                networks_to_static_ips[job_network.name] ||= []
                networks_to_static_ips[job_network.name] << StaticIpToAzs.new(static_ip, filtered_az_names)
              end
            end

            new(networks_to_static_ips, job_name)
          end

          def initialize(networks_to_static_ips, job_name)
            @networks_to_static_ips = networks_to_static_ips
            @job_name = job_name
          end

          def validate_azs_are_declared_in_job_and_subnets(desired_azs)
            if desired_azs.nil? &&
              @networks_to_static_ips.any? do |_, static_ips_to_az|
                static_ips_to_az.any? { |static_ip_to_az| !static_ip_to_az.az_names.any?(&:nil?) }
              end

              raise JobInvalidAvailabilityZone,
                "Instance group '#{@job_name}' subnets declare availability zones and the instance group does not"
            end
          end

          def validate_ips_are_in_desired_azs(desired_azs)
            return if desired_azs.to_a.empty?

            desired_az_names = desired_azs.to_a.map(&:name)
            @networks_to_static_ips.each do |_, static_ips_to_az|
              non_desired_ip_to_az = static_ips_to_az.find do |static_ip_to_az|
                !(desired_az_names & static_ip_to_az.az_names).any?
              end

              if non_desired_ip_to_az
                raise JobStaticIpsFromInvalidAvailabilityZone,
                  "Instance group '#{@job_name}' declares static ip '#{base_addr(non_desired_ip_to_az.ip)}' which does not belong to any of the instance group's availability zones."
              end
            end
          end

          def azs_to_networks
            result = {}
            @networks_to_static_ips.each do |network_name, static_ips_to_azs|
              static_ips_to_azs.each do |static_ip_to_azs|
                static_ip_to_azs.az_names.each do |az_name|
                  result[az_name][network_name] ||= []
                  result[az_name][network_name] << static_ip_to_azs.ip
                end
              end
            end
          end

          def distribute_evenly_per_zone
            best_combination = BruteForceIpAllocation.new(@networks_to_static_ips).find_best_combination
            if best_combination.nil?
              raise InstanceGroupNetworkInstanceIpMismatch, "Failed to evenly distribute static IPs between zones for instance group '#{@job_name}'"
            end
            @networks_to_static_ips = best_combination
          end

          def next_ip_for_network(network)
            unclaimed_networks_to_static_ips[network.name].first
          end

          def claim_in_az(ip, az_name)
            @networks_to_static_ips.each do |_, static_ips_to_azs|
              static_ips_to_azs.each do |static_ip_to_azs|
                if static_ip_to_azs.ip == ip
                  static_ip_to_azs.claimed = true
                  static_ip_to_azs.az_names = [az_name]
                end
              end
            end
          end

          def delete(ip)
            @networks_to_static_ips.each do |_, static_ip_to_azs|
              static_ip_to_azs.delete_if { |static_ip_to_az| static_ip_to_az.ip == ip }
            end
          end

          def find_by_network_and_ip(network, ip)
            unclaimed_networks_to_static_ips[network.name].find { |static_ip_to_azs| static_ip_to_azs.ip == ip }
          end

          def find_by_network_and_az(network, az_name)
            unclaimed_networks_to_static_ips[network.name].find { |static_ip_to_azs| static_ip_to_azs.az_names.include?(az_name) }
          end

          def unclaimed_networks_to_static_ips
            Hash[@networks_to_static_ips.map { |network_name, static_ips_to_azs| [network_name, static_ips_to_azs.reject(&:claimed)] }]
          end

          class StaticIpToAzs < Struct.new(:ip, :az_names, :claimed); end
        end
      end
    end
  end
end
