module Bosh::Director
  module IpUtil
    def each_ip(range_string_or_strings)
      [range_string_or_strings].flatten.compact.each do |range_string|
        string_to_range(range_string).each do |ip|
          yield ip
        end
      end
    rescue ArgumentError => e
      raise NetworkInvalidIpRangeFormat, e.message
    end

    def ip_to_i(ip)
      to_ipaddr(ip).to_i
    end

    def to_ipaddr(ip)
      Bosh::Director::IpAddrOrCidr.new(ip)
    end

    # @param [Integer] ip Integer IP representation
    # @return [String] Human-readable IP representation
    def format_ip(ip)
      to_ipaddr(ip)
    end

    def format_cidr_ip(ip)
      ip.to_cidr_s
    end

    def ip_address?(ip)
      ip_address = Bosh::Director::IpAddrOrCidr.new(ip)

      ip_address.ipv4? || ip_address.ipv6?
    rescue
      return false
    end

    private

    def string_to_range(range_string)
      parts = range_string.split('-').map { |part| part.strip }

      unless [1,2].include?(parts.length)
        raise NetworkInvalidIpRangeFormat, "Invalid IP range format: #{range_string}"
      end

      if parts.size == 1
        cidr_range = Bosh::Director::IpAddrOrCidr.new(parts[0]).to_range
        first_ip = cidr_range.first
        last_ip = cidr_range.last

      elsif parts.size == 2
        first_ip = Bosh::Director::IpAddrOrCidr.new(parts[0])
        last_ip = Bosh::Director::IpAddrOrCidr.new(parts[1])

        unless first_ip.count == 1 && last_ip.count == 1
          raise NetworkInvalidIpRangeFormat, "Invalid IP range format: #{range_string}"
        end
      end

      (first_ip.to_i .. last_ip.to_i)
    end
  end
end
