module Bosh::Director::DeploymentPlan
  class InMemoryIpRepo
    include Bosh::Director::IpUtil

    def initialize(logger)
      @logger = logger
      @ips = []
      @recently_released_ips = []
    end

    def delete(ip, subnet)
      ip = ip_to_netaddr(ip)

      if subnet.range.contains?(ip)
        entry_to_delete = {ip: ip.to_i, subnet: subnet}
        @logger.debug("Deleting ip '#{ip.ip}' for #{subnet.network}")
        @ips.delete(entry_to_delete)
        @recently_released_ips << (entry_to_delete)
        return
      end

      message = "Can't release IP '#{ip.ip}' back to '#{subnet.network.name}' network: " +
        "it's neither in dynamic nor in static pool"
      raise Bosh::Director::NetworkReservationIpNotOwned, message
    end

    def add(ip, subnet)
      ip = ip_to_netaddr(ip)

      if subnet.restricted_ips.include?(ip.to_i)
        message = "Failed to reserve IP '#{ip.ip}' for network '#{subnet.network.name}': IP belongs to reserved range"
        @logger.error(message)
        raise Bosh::Director::NetworkReservationIpReserved, message
      end

      if subnet.range.contains?(ip)
        entry_to_add = {ip: ip.to_i, subnet: subnet}

        if @ips.include?(entry_to_add)
          message = "Failed to reserve IP '#{ip.ip}' for '#{subnet.network.name}': already reserved"
          @logger.error(message)
          raise Bosh::Director::NetworkReservationAlreadyInUse, message
        end

        @logger.debug("Reserving ip '#{ip.ip}' for #{subnet.network}")
        @ips << entry_to_add
        @recently_released_ips.delete(entry_to_add)

        return
      end

      message = "Can't reserve IP '#{ip.ip}' to '#{subnet.network.name}' network: " +
        "it's neither in dynamic nor in static pool"
      raise Bosh::Director::NetworkReservationIpNotOwned, message
    end

    def get_dynamic_ip(subnet)
      (0...subnet.range.size).each do |i|
        return subnet.range[i] if available_for_dynamic?(subnet.range[i], subnet)
      end

      entry = @recently_released_ips.find { |entry| entry[:subnet] == subnet }
      unless entry.nil?
        return ip_to_netaddr(entry[:ip])
      end

      nil
    end

    private

    def available_for_dynamic?(ip, subnet)
      return false unless subnet.range.contains?(ip)
      return false if subnet.static_ips.include?(ip.to_i)
      return false if subnet.restricted_ips.include?(ip.to_i)
      return false if @recently_released_ips.include?({ip: ip.to_i, subnet: subnet})
      return false if @ips.include?({ip: ip.to_i, subnet: subnet})
      true
    end
  end
end
