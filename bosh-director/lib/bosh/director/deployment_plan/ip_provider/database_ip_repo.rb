module Bosh::Director::DeploymentPlan
  class DatabaseIpRepo
    include Bosh::Director::IpUtil

    def initialize(logger)
      @logger = logger
    end

    def delete(ip, network_name)
      cidr_ip = CIDRIP.new(ip)

      ip_address = Bosh::Director::Models::IpAddress.first(
        address: cidr_ip.to_i,
        network_name: network_name,
      )

      if ip_address
        @logger.debug("Releasing ip '#{cidr_ip}'")
        ip_address.destroy
      else
        @logger.debug("Skipping releasing ip '#{cidr_ip}' for #{network_name}: not reserved")
      end
    end
  end
end
