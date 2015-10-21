module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class StaticIpsAvailabilityZonePicker
          def place_and_match_in(desired_azs, job_networks, desired_instances, existing_instance_models, job_name)
            unplaced_existing_instances =  UnplacedExistingInstances.new(existing_instance_models)
            placed_instances = PlacedDesiredInstances.new(desired_azs)
            static_ips_to_azs = StaticIPsToAZs.new(job_networks, job_name)
            static_ips_to_azs.validate_ips_are_in_desired_azs(desired_azs)
            static_ips_to_azs.validate_even_ip_distribution

            desired_instances = desired_instances.dup

            existing_instance_models.each do |existing_instance_model|
              az_name = existing_instance_model.availability_zone
              instance_ips = existing_instance_model.ip_addresses.map { |ip_address| ip_address.address }
              instance_static_ip_to_az = static_ips_to_azs.find do |static_ip_to_az|
                instance_ips.include?(static_ip_to_az.ip)
              end
              if instance_static_ip_to_az
                static_ips_to_azs.claim(instance_static_ip_to_az)
                existing = unplaced_existing_instances.claim_instance(existing_instance_model)
                az = to_az(az_name, desired_azs)
                placed_instances.record_placement(az, desired_instances.shift, existing)
              end
            end

            desired_instances.each do |desired_instance|
              static_ip_to_az = static_ips_to_azs.shift
              az = to_az(static_ip_to_az.az_name, desired_azs) if static_ip_to_az
              existing = unplaced_existing_instances.claim_instance_for_az(az)
              placed_instances.record_placement(az, desired_instance, existing)
            end

            {
              desired_new: placed_instances.absent,
              desired_existing: placed_instances.existing,
              obsolete: unplaced_existing_instances.unclaimed,
            }
          end

          private

          def to_az(az_name, desired_azs)
            desired_azs.to_a.find { |az| az.name == az_name }
          end
        end

        class StaticIPsToAZs
          class StaticIPToAZ < Struct.new(:az_name, :ip, :network);
            def inspect
              formatted_ip = NetAddr::CIDR.create(ip).ip
              "<StaticIPToAZ: az=#{az_name} ip=#{formatted_ip} network=#{network.name}>"
            end
          end
          include Enumerable

          def initialize(job_networks, job_name)
            @job_name = job_name

            @static_ips_to_azs = []
            job_networks.each do |job_network|
              static_ips = job_network.static_ips if job_network.respond_to?(:static_ips) && job_network.static_ips
              next unless static_ips
              subnets = job_network.deployment_network.subnets

              static_ips.each do |static_ip|
                subnet_for_ip = subnets.find { |subnet| subnet.static_ips.include?(static_ip) }
                if subnet_for_ip.nil?
                  formatted_ip = NetAddr::CIDR.create(static_ip).ip
                  raise JobNetworkInstanceIpMismatch, "Job '#{job_name}' declares static ip '#{formatted_ip}' which belongs to no subnet"
                end
                unless subnet_for_ip.availability_zone_names.nil?
                  zone_name = subnet_for_ip.availability_zone_names.first
                  @static_ips_to_azs << StaticIPToAZ.new(zone_name, static_ip, job_network)
                end
              end
            end

            @static_ips_to_azs
          end

          def validate_ips_are_in_desired_azs(desired_azs)
            if desired_azs.nil? &&
              @static_ips_to_azs.any? { |static_ip_to_az| !static_ip_to_az.az_name.nil? }

              raise JobInvalidAvailabilityZone,
                "Job '#{@job_name}' subnets declare availability zones and the job does not"
            end

            return if desired_azs.to_a.empty?

            desired_az_names = desired_azs.to_a.map(&:name)
            non_desired_ip_to_az = @static_ips_to_azs.find do |static_ip_to_az|
              !desired_az_names.include?(static_ip_to_az.az_name)
            end

            if non_desired_ip_to_az
              formatted_ip = NetAddr::CIDR.create(non_desired_ip_to_az.ip).ip

              raise JobStaticIpsFromInvalidAvailabilityZone,
                "Job '#{@job_name}' declares static ip '#{formatted_ip}' which does not belong to any of the job's availability zones."
            end
          end

          def validate_even_ip_distribution
            hash = {}
            @static_ips_to_azs.each do |static_ip|
              hash[static_ip.network.name] ||= {}
              hash[static_ip.network.name][static_ip.az_name] ||= 0
              hash[static_ip.network.name][static_ip.az_name] += 1
            end
            if hash.values.uniq.size > 1
              raise Bosh::Director::JobNetworkInstanceIpMismatch,
                "Job '#{@job_name}' networks must declare the same number of static IPs per AZ in each network"
            end
          end

          def each(&block)
            @static_ips_to_azs.each(&block)
          end

          def claim(static_ip)
            @static_ips_to_azs.delete(static_ip)
          end

          def shift
            @static_ips_to_azs.shift
          end
        end
      end
    end
  end
end
