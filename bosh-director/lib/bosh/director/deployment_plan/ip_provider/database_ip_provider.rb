module Bosh::Director::DeploymentPlan
  class DatabaseIpProvider
    include Bosh::Director::IpUtil

    # @param [NetAddr::CIDR] range
    # @param [String] network_name
    def initialize(range, network_name, restricted_ips, static_ips)
      @range = range
      @network_name = network_name
      @restricted_ips = restricted_ips
      @static_ips = static_ips
    end

    # @return [Integer] ip
    def allocate_dynamic_ip
      # find address that doesn't have subsequent address
      addrs = Set.new(network_addresses)
      addrs << @range.first(Objectify: true).to_i - 1 if addrs.empty?

      addrs.merge(@restricted_ips.to_a) unless @restricted_ips.empty?
      addrs.merge(@static_ips.to_a) unless @static_ips.empty?

      addr = addrs.to_a.sort.find { |a| !addrs.include?(a+1) }
      ip_address = NetAddr::CIDRv4.new(addr+1)

      return nil unless @range == ip_address || @range.contains?(ip_address)

      return nil unless reserve(ip_address)

      ip_address.to_i
    end

    # @param [NetAddr::CIDR] ip
    def reserve_ip(ip)
      return nil if @restricted_ips.include?(ip.to_i)

      reserve(ip)

      @static_ips.include?(ip.to_i) ? :static : :dynamic
    end

    # @param [NetAddr::CIDR] ip
    def release_ip(ip)
      ip_address = Bosh::Director::Models::IpAddress.first(
        address: ip.to_i,
        network_name: @network_name,
      )

      unless ip_address
        raise Bosh::Director::NetworkReservationIpNotOwned,
          "Can't release IP `#{format_ip(ip)}' " +
            "back to `#{@network_name}' network: " +
            "it's neither in dynamic nor in static pool"
      end

      ip_address.destroy
    end

    private

    # @param [NetAddr::CIDR] ip
    def reserve(ip)
      Bosh::Director::Models::IpAddress.new(
        address: ip.to_i,
        network_name: @network_name,
      ).save
    rescue Sequel::DatabaseError
      nil
    end

    def network_addresses
      Bosh::Director::Models::IpAddress.select(:address)
        .where(network_name: @network_name).all.map { |a| a.address }
    end
  end
end
