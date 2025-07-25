require 'ipaddr'

module Bosh
  module Director
    class IpAddrOrCidr
      include Comparable

      delegate :==, :include?, :ipv4?, :ipv6?, :netmask, :mask, :to_i, :to_range, :to_s, :to_string, :prefix, :succ, :<=>, to: :@ipaddr
      alias :to_s :to_s

      def initialize(ip_or_cidr)
        @ipaddr =
          if ip_or_cidr.kind_of?(IpAddrOrCidr)
            IPAddr.new(ip_or_cidr.to_cidr_s)
          elsif ip_or_cidr.kind_of?(Integer)
            IPAddr.new(ip_or_cidr, inet_type_for(ip_or_cidr))
          else
            begin
              IPAddr.new(ip_or_cidr)
            rescue IPAddr::InvalidAddressError => e
              raise e, "Invalid IP or CIDR format: #{ip_or_cidr}"
            end
          end
      end

      def each_base_address(prefix_length)
        if @ipaddr.ipv4?
          bits = 32
        elsif @ipaddr.ipv6?
          bits = 128
        end
        step_size = 2**(bits - prefix_length.to_i)
        base_address_int = @ipaddr.to_i

        while base_address_int <= @ipaddr.to_range.last.to_i
          yield base_address_int
          base_address_int += step_size
        end
      end

      def count
        (@ipaddr.to_range.last.to_i - @ipaddr.to_range.first.to_i) + 1
      end

      def to_cidr_s
        "#{@ipaddr}/#{@ipaddr.prefix}"
      end

      def to_range
        @ipaddr.to_range
      end

      def succ
        next_ip = @ipaddr.succ
        Bosh::Director::IpAddrOrCidr.new(next_ip.to_i)
      end

      def <=>(other)
        @ipaddr.to_i <=> other.to_i
      end

      def last
        Bosh::Director::IpAddrOrCidr.new(@ipaddr.to_range.last.to_i)
      end

      def first
        Bosh::Director::IpAddrOrCidr.new(@ipaddr.to_range.first.to_i)
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
