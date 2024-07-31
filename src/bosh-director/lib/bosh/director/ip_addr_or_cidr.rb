require 'ipaddr'

module Bosh
  module Director
    class IpAddrOrCidr
      delegate :==, :ipv4?, :ipv6?, :to_i, :to_string, to: :@ipaddr
      alias :to_s :to_string

      def initialize(ip_or_cidr)
        @ipaddr =
          if ip_or_cidr.kind_of?(Integer)
            IPAddr.new(ip_or_cidr, inet_type_for(ip_or_cidr))
          elsif ip_or_cidr.respond_to?(:ip)
            IPAddr.new(ip_or_cidr.ip)
          else
            IPAddr.new(ip_or_cidr)
          end
      end

      def count
        (@ipaddr.to_range.last.to_i - @ipaddr.to_range.first.to_i) + 1
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
