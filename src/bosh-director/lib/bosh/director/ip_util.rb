module Bosh::Director
  module IpUtil
    def each_ip(ranges, &block)
      if ranges.kind_of?(Array)
        ranges.each do |range|
          process_range(range, &block)
        end
      elsif ranges.kind_of?(String)
        process_range(ranges, &block)
      elsif !ranges.nil?
        raise ArgumentError,
              "Unknown range type, must be list or a string: " +
              "#{ranges.class} #{ranges}"
      end
    end

    def ip_to_i(ip)
      CIDRIP.parse(ip).addr
    end

    def ip_to_netaddr(ip)
      CIDRIP.parse(ip).netaddr
    end

    # @param [Integer] ip Integer IP representation
    # @return [String] Human-readable IP representation
    def format_ip(ip)
      CIDRIP.parse(ip).to_s
    end

    def ip_address?(ip)
      ip_address = IPAddr.new(ip)
      return ip_address.ipv4? || ip_address.ipv6?
    rescue
      return false
    end

    private

    def process_range(range)
      parts = range.split("-")
      parts.each { |part| part.strip! }
      if parts.size == 1 && parts[0].include?('/')
        range = CIDR.parse(parts[0])
        first_ip = range.nth(0).addr
        last_ip = range.nth(range.len - 1).addr
        (first_ip .. last_ip).each do |ip|
          yield ip
        end
      elsif parts.size == 1
        ip = CIDRIP.parse(parts[0]).addr
        yield ip
      elsif parts.size == 2
        first_ip = CIDRIP.parse(parts[0])
        last_ip = CIDRIP.parse(parts[1])
        (first_ip.addr .. last_ip.addr).each do |ip|
          yield ip
        end
      else
        raise NetworkInvalidIpRangeFormat,
          "Invalid IP range format: #{range}"
      end
    rescue ArgumentError, NetAddr::ValidationError => e
      raise NetworkInvalidIpRangeFormat, "Invalid IP range format: #{range} (#{e.message})"
    end

    class CIDR

      def CIDR.parse(ip)
        CIDR.new(ip).netaddr
      end

      def initialize(cidr)
        if cidr.kind_of?(NetAddr::IPv4Net) || cidr.kind_of?(NetAddr::IPv6Net)
          @cidr = cidr
        else
          @cidr = parse(cidr)
        end
        @version = @cidr.version
      end

      def netaddr
        @cidr
      end

      def netmask
        if @version == 4
          @cidr.netmask.extended
        else
          NetAddr::IPv6.new(@cidr.netmask.mask).to_s
        end
      end

      def to_s
        @cidr.to_s
      end

      private

      def parse(cidr)
        NetAddr::IPv4Net.parse(cidr)
      rescue NetAddr::ValidationError => e_v4
        begin
          NetAddr::IPv6Net.parse(cidr)
        rescue NetAddr::ValidationError => e_v6
          raise NetAddr::ValidationError, "IP CIDR format #{ip} is neither a valid IPv4 nor IPv6 format: #{e_v4} / #{e_v6}"
        end
      end
    end

    class CIDRIP

      def CIDRIP.parse(ip)
        CIDRIP.new(ip).netaddr
      end

      def initialize(ip)
        if ip.kind_of?(NetAddr::IPv4) || ip.kind_of?(NetAddr::IPv6)
          @ip = ip
        else
          @ip = parse(ip)
        end
      end

      def netaddr
        @ip
      end

      def addr
        @ip.addr
      end

      def to_s
        @ip.to_s
      end

      def stringify
        @ip.addr.to_s
      end

      private

      def parse(ip)
        parse_ip_v4(ip)
      rescue NetAddr::ValidationError => e_v4
        begin
          parse_ip_v6(ip)
        rescue NetAddr::ValidationError => e_v6
          raise NetAddr::ValidationError, "IP format #{ip} is neither a valid IPv4 nor IPv6 format: #{e_v4} / #{e_v6}"
        end
      end

      def parse_ip_v6(ip)
        if ip.kind_of?(Integer)
          NetAddr::IPv6.new(ip)
        else ip.kind_of?(String)
          NetAddr::IPv6.parse(ip)
        end
      end

      def parse_ip_v4(ip)
        if ip.kind_of?(Integer)
          NetAddr::IPv4.new(ip)
        else ip.kind_of?(String)
          NetAddr::IPv4.parse(ip)
        end
      end
    end
  end
end
