require 'netaddr'

module Bosh::Director
  module IpUtil
    def each_ip(range_string_or_strings)
      [range_string_or_strings].flatten.compact.each do |range_string|
        string_to_range(range_string).each do |ip|
          yield ip
        end
      end
    rescue ArgumentError, NetAddr::ValidationError => e
      raise NetworkInvalidIpRangeFormat, e.message
    end

    def ip_to_i(ip)
      unless ip.kind_of?(Integer)
        unless ip.kind_of?(NetAddr::CIDR)
          ip = NetAddr::CIDR.create(ip)
        end
        ip = ip.to_i
      end
      ip
    end

    def ip_to_netaddr(ip)
      unless ip.kind_of?(NetAddr::CIDR)
        ip = NetAddr::CIDR.create(ip)
      end
      ip
    end

    # @param [Integer] ip Integer IP representation
    # @return [String] Human-readable IP representation
    def format_ip(ip)
      ip_to_netaddr(ip).ip
    end

    def ip_address?(ip)
      ip_address = IPAddr.new(ip)

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
        cidr_range = NetAddr::CIDR.create(parts[0])
        first_ip = cidr_range.first(:Objectify => true)
        last_ip = cidr_range.last(:Objectify => true)

      elsif parts.size == 2
        first_ip = NetAddr::CIDR.create(parts[0])
        last_ip = NetAddr::CIDR.create(parts[1])

        unless first_ip.size == 1 && last_ip.size == 1
          raise NetworkInvalidIpRangeFormat, "Invalid IP range format: #{range_string}"
        end
      end

      (first_ip.to_i .. last_ip.to_i)
    end

    class CIDRIP
      def initialize(ip)
        if ip.kind_of?(NetAddr::CIDR)
          @cidr = ip
        else
          @cidr = NetAddr::CIDR.create(ip)
        end
      end

      def to_i
        @cidr.to_i
      end

      def to_s
        @cidr.ip.to_s
      end
    end
  end
end
