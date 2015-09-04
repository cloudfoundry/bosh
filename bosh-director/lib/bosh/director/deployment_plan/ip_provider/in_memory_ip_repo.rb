module Bosh::Director::DeploymentPlan
  class InMemoryIpRepo
    include Bosh::Director::IpUtil

    def initialize(logger)
      @logger = logger
      @ips = []
      @recently_released_ips = []
    end

    def delete(ip, network_name)
      ip = ip_to_netaddr(ip)
      entry_to_delete = {ip: ip.to_i, network_name: network_name}

      @logger.debug("Deleting ip '#{ip.ip}' for #{network_name}")
      @ips.delete(entry_to_delete)
      @recently_released_ips << (entry_to_delete)
    end

    def add(reservation)
      ip = ip_to_netaddr(reservation.ip)
      network_name = reservation.network.name

      entry_to_add = {ip: ip.to_i, network_name: network_name}

      if @ips.include?(entry_to_add)
        message = "Failed to reserve IP '#{ip.ip}' for '#{network_name}': already reserved"
        @logger.error(message)
        raise Bosh::Director::NetworkReservationAlreadyInUse, message
      end

      @logger.debug("Reserving ip '#{ip.ip}' for #{network_name}")
      @ips << entry_to_add
      @recently_released_ips.delete(entry_to_add)
    end

    def get_dynamic_ip(subnet)
      (0...subnet.range.size).each do |i|
        return subnet.range[i] if available_for_dynamic?(subnet.range[i], subnet)
      end

      entry = @recently_released_ips.find do |entry|
        entry[:network_name] == subnet.network.name && subnet.range.contains?(entry[:ip])
      end
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
      return false if @recently_released_ips.include?({ip: ip.to_i, network_name: subnet.network.name})
      return false if @ips.include?({ip: ip.to_i, network_name: subnet.network.name})
      true
    end
  end
end
