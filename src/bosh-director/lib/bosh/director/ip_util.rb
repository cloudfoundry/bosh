module Bosh::Director
  module IpUtil
    def each_ip(range_string_or_strings, expanded = true)
      [range_string_or_strings].flatten.compact.each do |range_string|
        string_to_range(range_string, expanded).each do |ip_or_range|
          yield ip_or_range
        end
      end
    rescue ArgumentError => e
      raise NetworkInvalidIpRangeFormat, e.message
    end

    def to_ipaddr(ip)
      Bosh::Director::IpAddrOrCidr.new(ip)
    end

    def base_addr(ip)
      Bosh::Director::IpAddrOrCidr.new(ip).base_addr
    end

    def ip_address?(ip)
      ip_address = Bosh::Director::IpAddrOrCidr.new(ip)

      ip_address.ipv4? || ip_address.ipv6?
    rescue
      return false
    end

    def ip_in_array?(ip_to_check, ip_objects_array)
      ip_to_check = Bosh::Director::IpAddrOrCidr.new(ip_to_check)

      ip_objects_array.any? do |ip_object|
        ip_object.include?(ip_to_check)
        rescue IPAddr::InvalidAddressError
        false
      end
    end

    private

    def string_to_range(range_string, expanded)
      parts = range_string.split('-').map { |part| part.strip }

      if parts.size == 1
        if expanded
          cidr_range = Bosh::Director::IpAddrOrCidr.new(parts[0]).to_range
          first_ip = Bosh::Director::IpAddrOrCidr.new(cidr_range.first.to_i)
          last_ip = Bosh::Director::IpAddrOrCidr.new(cidr_range.last.to_i)
          (first_ip .. last_ip)
        else
          [Bosh::Director::IpAddrOrCidr.new(parts[0])]
        end
      elsif parts.size == 2
        first_ip = Bosh::Director::IpAddrOrCidr.new(parts[0])
        last_ip = Bosh::Director::IpAddrOrCidr.new(parts[1])
        unless first_ip.count == 1 && last_ip.count == 1
          raise NetworkInvalidIpRangeFormat, "Invalid IP range format: #{range_string}"
        end
        if expanded
          (first_ip .. last_ip)
        else
          ip_range_to_cidr_list(first_ip, last_ip)
        end
      else
        raise NetworkInvalidIpRangeFormat, "Invalid IP range format: #{range_string}"
      end
    end

    def ip_range_to_cidr_list(first_ip, last_ip)
      cidr_blocks = []

      current_ip = first_ip

      while current_ip.to_i <= last_ip.to_i
        mask = current_ip.ipv4? ? 32 : 128

        while mask >= 0
          potential_subnet = Bosh::Director::IpAddrOrCidr.new("#{current_ip.base_addr}/#{mask}")

          first_ip_in_range = potential_subnet.first
          last_ip_in_range = potential_subnet.last

          if first_ip_in_range == current_ip && last_ip_in_range == last_ip
            cidr_blocks << potential_subnet
            current_ip = potential_subnet.last.succ
            break
          end

          if first_ip_in_range < current_ip || ( first_ip_in_range == current_ip && last_ip_in_range >= last_ip )
            previous_mask = mask + 1
            found_subnet = Bosh::Director::IpAddrOrCidr.new("#{current_ip.base_addr}/#{previous_mask}")
            cidr_blocks << found_subnet
            current_ip = found_subnet.last.succ
            break
          end

          mask -= 1
        end

        if current_ip.to_i > last_ip.to_i
          break
        end
      end
      cidr_blocks

    end
  end
end
