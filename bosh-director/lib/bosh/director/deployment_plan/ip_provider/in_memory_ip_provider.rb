module Bosh::Director
  module DeploymentPlan
    class InMemoryIpProvider
      include IpUtil

      def initialize(range, network_name, reserved_ips, static_ips)
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

        reserved_ips.each do |ip|
          @available_dynamic_ips.delete(ip)
        end

        static_ips.each do |ip|
          @available_dynamic_ips.delete(ip)
          @available_static_ips.add(ip)
        end

        # Keeping track of initial pools to understand
        # where to release no longer needed IPs
        @dynamic_ip_pool = @available_dynamic_ips.dup
        @static_ip_pool = @available_static_ips.dup
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
