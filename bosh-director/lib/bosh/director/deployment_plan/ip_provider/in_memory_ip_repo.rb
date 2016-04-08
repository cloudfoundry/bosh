module Bosh::Director::DeploymentPlan
  class InMemoryIpRepo
    include Bosh::Director::IpUtil

    def initialize(logger)
      @logger = Bosh::Director::TaggedLogger.new(logger, 'network-configuration')
      @mutex = Mutex.new
      @ips = []
      @recently_released_ips = []
    end

    def delete(ip, network_name)
      ip = ip_to_netaddr(ip)
      entry_to_delete = {ip: ip.to_i, network_name: network_name}

      @logger.debug("Deleting ip '#{ip.ip}' for #{network_name}")
      @mutex.synchronize do
        @ips.delete(entry_to_delete)
        @recently_released_ips << (entry_to_delete)
      end
    end

    def add(reservation)
      ip = ip_to_netaddr(reservation.ip)
      network_name = reservation.network.name
      @mutex.synchronize do
        add_ip(ip, network_name)
      end
    end

    def allocate_dynamic_ip(reservation, subnet)
      @mutex.synchronize do
        item = (0...subnet.range.size).find { |i| available_for_dynamic?(subnet.range[i], subnet) }

        if item.nil?
          entry = @recently_released_ips.find do |entry|
            entry[:network_name] == subnet.network_name && subnet.range.contains?(entry[:ip])
          end

          ip = ip_to_netaddr(entry[:ip]) unless entry.nil?
        else
          ip = subnet.range[item]
        end

        add_ip(ip, subnet.network_name) unless ip.nil?

        ip
      end
    end

    def contains_ip?(ip, network_name)
      @ips.include?({ip: ip.to_i, network_name: network_name})
    end

    private

    def add_ip(ip, network_name)
      if contains_ip?(ip, network_name)
        message = "Failed to reserve IP '#{ip.ip}' for '#{network_name}': already reserved"
        @logger.error(message)
        raise Bosh::Director::NetworkReservationAlreadyInUse, message
      end

      @logger.debug("Reserving ip '#{ip.ip}' for #{network_name}")

      entry_to_add = {ip: ip.to_i, network_name: network_name}
      @ips << entry_to_add
      @recently_released_ips.delete(entry_to_add)
    end

    def available_for_dynamic?(ip, subnet)
      return false unless subnet.range.contains?(ip)
      return false if subnet.static_ips.include?(ip.to_i)
      return false if subnet.restricted_ips.include?(ip.to_i)
      return false if @recently_released_ips.include?({ip: ip.to_i, network_name: subnet.network_name})
      return false if @ips.include?({ip: ip.to_i, network_name: subnet.network_name})

      true
    end
  end
end
