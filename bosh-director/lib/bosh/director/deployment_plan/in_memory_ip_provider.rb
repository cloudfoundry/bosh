module Bosh::Director
  module DeploymentPlan
    class InMemoryIpProvider
      include IpUtil

      def initialize(range, network_name)
        @range = range
        @network_name = network_name
        @available_dynamic_ips = Set.new
        @available_static_ips = Set.new
        @static_ip_pool = Set.new
        first_ip = @range.first(:Objectify => true)
        last_ip = @range.last(:Objectify => true)

        (first_ip.to_i .. last_ip.to_i).each do |ip|
          @available_dynamic_ips << ip
        end
        @dynamic_ip_pool = @available_dynamic_ips.dup
        blacklist_ip(@range.network(:Objectify => true))
      end

      def blacklist_ip(ip)
        unless @available_dynamic_ips.delete?(ip.to_i) && @dynamic_ip_pool.delete?(ip.to_i)
          raise NetworkReservedIpOutOfRange,
            "Reserved IP `#{format_ip(ip)}' is out of " +
              "network `#{@network_name}' range"
        end
      end

      def add_static_ip(ip)
        unless @available_dynamic_ips.delete?(ip.to_i) && @dynamic_ip_pool.delete?(ip.to_i)
          raise NetworkStaticIpOutOfRange,
            "Static IP `#{format_ip(ip)}' is out of " +
              "network `#{@network_name}' range"
        end
        @static_ip_pool.add(ip.to_i)
        @available_static_ips.add(ip.to_i)
      end

      def allocate_dynamic_ip
        ip = @available_dynamic_ips.first
        if ip
          @available_dynamic_ips.delete(ip)
        end
        ip
      end

      def reserve_ip(ip)
        ip = ip.to_i
        if @available_static_ips.delete?(ip)
          :static
        elsif @available_dynamic_ips.delete?(ip)
          :dynamic
        else
          nil
        end
      end

      def release_ip(ip)
        ip = ip.to_i
        if @dynamic_ip_pool.include?(ip)
          @available_dynamic_ips.add(ip)
        elsif @static_ip_pool.include?(ip)
          @available_static_ips.add(ip)
        else
          raise NetworkReservationIpNotOwned,
            "Can't release IP `#{format_ip(ip)}' " +
              "back to `#{@network_name}' network: " +
              "it's neither in dynamic nor in static pool"
        end
      end
    end
  end
end
