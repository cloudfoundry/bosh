module Bosh::Director::DeploymentPlan
  module NetworkPlanner
    class StaticIpRepo
      def initialize(job_networks, logger)
        @network_to_static_ips = {}
        job_networks.each do |job_network|
          if job_network.static_ips
            @network_to_static_ips[job_network] = job_network.static_ips.dup
          end
        end
        @logger = logger
      end

      def try_to_claim_ip(job_network, ip)
        @network_to_static_ips[job_network].delete(ip)
      end

      def claim_static_ip_for_az_and_network(az_name, job_network)
        static_ip = find_static_ip_for_az(az_name, job_network)
        @network_to_static_ips[job_network].delete(static_ip)
        static_ip
      end

      private

      def find_static_ip_for_az(az_name, job_network)
        static_ips = @network_to_static_ips[job_network]
        @logger.debug("choosing for ip in az: '#{az_name}' from list of static ips '#{static_ips.map { |ip| NetAddr::CIDR.create(ip).ip }}'")
        static_ips.find do |ip|
          ip_subnet = job_network.deployment_network.subnets.find { |subnet| subnet.static_ips.include?(ip) }
          @logger.debug("Found subnet #{ip_subnet} for IP: #{NetAddr::CIDR.create(ip).ip}")
          ip_subnet.availability_zone_names.to_a.first == az_name
        end
      end
    end
  end
end
