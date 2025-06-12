require 'ipaddr'

module Bosh
  module Director
    class IpAddrOrCidr
      delegate :==, :include?, :ipv4?, :ipv6?, :netmask, :to_i, :to_range, :to_string, :prefix, to: :@ipaddr
      alias :to_s :to_string

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
        # Determine the base address for the given prefix_length
        # We assume the prefix_length is a valid integer within the subnet
        if @ipaddr.ipv4?
          bits = 32
        elsif @ipaddr.ipv6?
          bits = 128
        end
        step_size = 2**(bits - prefix_length) # Calculate number of addresses per subnet
        base_address_int = @ipaddr.to_i
    
        # Yield each base address in this network
        while base_address_int <= @ipaddr.to_range.last.to_i
          yield base_address_int
          base_address_int += step_size
        end
      end

      def count
        (@ipaddr.to_range.last.to_i - @ipaddr.to_range.first.to_i) + 1
      end

      def to_cidr_s
        "#{@ipaddr.to_string}/#{@ipaddr.prefix}"
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
