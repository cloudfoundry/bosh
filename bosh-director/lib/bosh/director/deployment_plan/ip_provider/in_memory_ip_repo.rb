module Bosh::Director::DeploymentPlan
  class InMemoryIpRepo
    def initialize(logger)
      @logger = logger
      @ips = []
    end

    def delete(ip, subnet)
      if subnet.range.contains?(ip)
        entry_to_delete = {ip: ip.to_i, subnet: subnet}
        @ips.delete(entry_to_delete)
        return
      end

      message = "Can't release IP '#{ip.ip}' back to '#{subnet.network.name}' network: " +
        "it's neither in dynamic nor in static pool"
      raise Bosh::Director::NetworkReservationIpNotOwned, message
    end

    # @param [NetAddr::CIDR] ip
    # @param [DeploymentPlan::ManualNetworkSubnet] subnet
    def add(ip, subnet)
      if subnet.range.contains?(ip)
        entry_to_add = {ip: ip.to_i, subnet: subnet}

        if @ips.include?(entry_to_add)
          message = "Failed to reserve IP '#{ip.ip}' for '#{subnet.network.name}': already reserved"
          @logger.error(message)
          raise BD::NetworkReservationAlreadyInUse, message
        end

        @logger.debug("Releasing static ip '#{ip}' for #{subnet.network}")
        @ips << {ip: ip.to_i, subnet: subnet}
        return
      end

      message = "Can't reserve IP '#{ip.ip}' to '#{subnet.network.name}' network: " +
        "it's neither in dynamic nor in static pool"
      raise Bosh::Director::NetworkReservationIpNotOwned, message
    end
  end
end
