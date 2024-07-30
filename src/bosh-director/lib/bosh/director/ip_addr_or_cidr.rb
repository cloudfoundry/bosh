require 'ipaddr'

module Bosh
  module Director
    class IpAddrOrCidr
      delegate :==, :include?, :ipv4?, :ipv6?, :netmask, :to_i, :to_range, :to_string, to: :@ipaddr
      alias :to_s :to_string

      def initialize(ip_or_cidr)
        @ipaddr =
          if ip_or_cidr.kind_of?(IpAddrOrCidr)
            IPAddr.new(ip_or_cidr.to_s)
          elsif ip_or_cidr.kind_of?(Integer)
            IPAddr.new(ip_or_cidr, inet_type_for(ip_or_cidr))
          else
            IPAddr.new(ip_or_cidr)
          end
      end

      def count
        (@ipaddr.to_range.last.to_i - @ipaddr.to_range.first.to_i) + 1
      end

      def to_cidr_s
        "#{@ipaddr}/#{@ipaddr.prefix}"
      end

      private

      def max_addresses
        ipv4? ?  IPAddr::IN4MASK : IPAddr::IN6MASK
      end

      def inet_type_for(address_int)
        address_int <= IPAddr::IN4MASK ? Socket::AF_INET : Socket::AF_INET6
      end
    end
  end
end
