module Bosh::Director
  module DeploymentPlan
    class InMemoryIpProvider
      include IpUtil

      def initialize(range, network_name, reserved_ips, static_ips, logger)
        @range = range
        @network_name = network_name
        @network_desc = "network '#{@network_name}' (#{@range})"
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

        @logger = TaggedLogger.new(logger, 'network-configuration', 'in-memory-ip-provider')
      end

      def allocate_dynamic_ip(_)
        ip = @available_dynamic_ips.first
        if ip
          @logger.debug("Allocated dynamic IP '#{format_ip(ip)}' for #{@network_desc}")
          @available_dynamic_ips.delete(ip)
        end
        ip
      end

      def reserve_ip(reservation)
        ip = CIDRIP.new(reservation.ip)
        if @available_static_ips.delete?(ip.to_i)
          @logger.debug("Reserved static ip '#{ip}' for #{@network_desc}")
          :static
        elsif @available_dynamic_ips.delete?(ip.to_i)
          @logger.debug("Reserved dynamic ip '#{ip}' for #{@network_desc}")
          :dynamic
        else
          if reservation.resolved?
            # if reservation is not resolved it is created from existing instance
            # DatabaseIpProvider can verify if IP belongs to the same instance
            # InMemoryIpProvider has no knowledge which instance is requesting IP
            # so we allow this reservation to happen
            message = "Failed to reserve ip '#{ip}' for #{@network_desc}: already reserved"
            @logger.error(message)
            raise NetworkReservationAlreadyInUse, message
          end
        end
      end

      def release_ip(ip)
        ip = CIDRIP.new(ip)
        if @dynamic_ip_pool.include?(ip.to_i)
          @logger.debug("Releasing dynamic ip '#{ip}' for #{@network_desc}")
          @available_dynamic_ips.add(ip.to_i)
        elsif @static_ip_pool.include?(ip.to_i)
          @logger.debug("Releasing static ip '#{ip}' for #{@network_desc}")
          @available_static_ips.add(ip.to_i)
        else
          @logger.debug("Failed to release ip '#{ip}' for #{@network_desc}: does not belong to static or dynamic pool")
          raise NetworkReservationIpNotOwned,
            "Can't release IP `#{ip}' " +
              "back to `#{@network_name}' network: " +
              "it's neither in dynamic nor in static pool"
        end
      end
    end
  end
end
