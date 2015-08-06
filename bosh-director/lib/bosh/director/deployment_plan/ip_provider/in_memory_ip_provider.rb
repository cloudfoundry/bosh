module Bosh::Director
  module DeploymentPlan
    class InMemoryIpProvider
      include IpUtil

      def initialize(range, network_name, restricted_ips, static_ips, logger)
        @range = range
        @network_name = network_name
        @network_desc = "network '#{@network_name}' (#{@range})"
        @restricted_ips = Set.new(restricted_ips)
        @available_static_ips = Set.new(static_ips)

        @static_ip_pool = @available_static_ips.dup
        @recently_released_ips = Set.new
        @reserved_dynamic_ips = Set.new

        @logger = TaggedLogger.new(logger, 'network-configuration', 'in-memory-ip-provider')
      end

      def allocate_dynamic_ip(_)
        ip = find_next_available_dynamic_ip
        if ip
          @logger.debug("Allocated dynamic IP '#{format_ip(ip)}' for #{@network_desc}")
          @reserved_dynamic_ips.add(ip)
        end
        ip
      end

      def reserve_ip(reservation)
        ip = CIDRIP.new(reservation.ip)
        if @available_static_ips.delete?(ip.to_i)
          reservation.validate_type(StaticNetworkReservation)
          @logger.debug("Reserved static ip '#{ip}' for #{@network_desc}")

        elsif available_for_dynamic?(ip)
          reservation.validate_type(DynamicNetworkReservation)
          @reserved_dynamic_ips.add(ip.to_i)
          @logger.debug("Reserved dynamic ip '#{ip}' for #{@network_desc}")

        elsif reservation.is_a?(ExistingNetworkReservation)
          # for existing reservations DatabaseIpProvider can verify if IP belongs to the same instance
          # InMemoryIpProvider has no knowledge which instance is requesting IP
          # so we allow this reservation to happen unless it is restricted now
          if @restricted_ips.include?(ip.to_i)
            @logger.debug("IP '#{ip}' is in reserved range now")
            raise NetworkReservationIpReserved, "IP '#{ip}' is in reserved range now"
          end
        else
          message = "Failed to reserve ip '#{ip}' for #{@network_desc}: already reserved"
          @logger.error(message)
          raise NetworkReservationAlreadyInUse, message
        end
      end

      def release_ip(ip)
        ip = CIDRIP.new(ip)
        if @static_ip_pool.include?(ip.to_i)
          @logger.debug("Releasing static ip '#{ip}' for #{@network_desc}")
          @available_static_ips.add(ip.to_i)
        elsif belongs_to_dynamic_pool?(ip)
          @logger.debug("Releasing dynamic ip '#{ip}' for #{@network_desc}")
          @recently_released_ips.add(ip.to_i)
        else
          @logger.debug("Failed to release ip '#{ip}' for #{@network_desc}: does not belong to static or dynamic pool")
          raise NetworkReservationIpNotOwned,
            "Can't release IP `#{ip}' " +
              "back to `#{@network_name}' network: " +
              "it's neither in dynamic nor in static pool"
        end
      end

      private

      def find_next_available_dynamic_ip
        (0...@range.size).each do |i|
          return @range[i].to_i if available_for_dynamic?(@range[i])
        end

        ip = @recently_released_ips.first
        if ip
          @recently_released_ips.delete(ip)
          return ip
        end

        nil
      end

      def available_for_dynamic?(ip)
        !@reserved_dynamic_ips.include?(ip.to_i) &&
          belongs_to_dynamic_pool?(ip) &&
          !@restricted_ips.include?(ip.to_i)
      end

      def belongs_to_dynamic_pool?(ip)
        @range.contains?(ip.to_i) &&
          !@static_ip_pool.include?(ip.to_i)
      end
    end
  end
end
