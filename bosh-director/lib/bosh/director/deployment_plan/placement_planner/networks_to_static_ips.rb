module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class NetworksToStaticIps
          extend Bosh::Director::IpUtil

          def self.create(job_networks, job_name)
            networks_to_static_ips = {}

            job_networks.each do |job_network|
              next unless job_network.static?
              subnets = job_network.deployment_network.subnets

              job_network.static_ips.each do |static_ip|
                subnet_for_ip = subnets.find { |subnet| subnet.static_ips.include?(static_ip) }
                if subnet_for_ip.nil?
                  raise JobNetworkInstanceIpMismatch, "Job '#{job_name}' declares static ip '#{format_ip(static_ip)}' which belongs to no subnet"
                end
                unless subnet_for_ip.availability_zone_names.nil?
                  networks_to_static_ips[job_network.name] ||= []
                  networks_to_static_ips[job_network.name] << StaticIpToAzs.new(static_ip, subnet_for_ip.availability_zone_names)
                end
              end
            end

            new(networks_to_static_ips, job_name)
          end

          def initialize(networks_to_static_ips, job_name)
            @networks_to_static_ips = networks_to_static_ips
            @job_name = job_name
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
              raise JobNetworkInstanceIpMismatch, "Failed to evenly distribute static IPs between zones for job '#{@job_name}'"
            end
            @networks_to_static_ips = best_combination
          end

          def take_next_ip_for_network(network)
            @networks_to_static_ips[network.name].shift
          end

          def claim(ip)
            @networks_to_static_ips.each do |_, static_ip_to_azs|
              static_ip_to_azs.delete_if { |static_ip_to_azs| static_ip_to_azs.ip == ip }
            end
          end

          def take_next_ip_for_network_and_az(network, az_name)
            static_ip_to_azs = @networks_to_static_ips[network.name].find { |static_ip_to_azs| static_ip_to_azs.az_names.include?(az_name) }
            @networks_to_static_ips[network.name].delete(static_ip_to_azs)
            static_ip_to_azs
          end

          def find_by_network_and_ip(network, ip)
            @networks_to_static_ips[network.name].find { |static_ip_to_azs| static_ip_to_azs.ip == ip }
          end

          private

          class StaticIpToAzs < Struct.new(:ip, :az_names); end
        end
      end
    end
  end
end
