module Bosh::Director
  module DeploymentPlan
    class IpProviderV2
      include IpUtil

      def initialize(ip_repo, using_global_networking, logger)
        @logger = logger
        @ip_repo = ip_repo
        @using_global_networking = using_global_networking
      end

      def release(reservation)
        return unless reservation.network.is_a?(ManualNetwork)

        if reservation.ip.nil?
          @logger.error("Failed to release IP for manual network '#{reservation.network.name}': IP must be provided")
          raise Bosh::Director::NetworkReservationIpMissing, "Can't release reservation without an IP"
        else
          @ip_repo.delete(reservation.ip, reservation.network.name)
        end
      end

      def reserve(reservation)
        if @using_global_networking
          return reservation.network.reserve(reservation)
        end

        return unless reservation.network.is_a?(ManualNetwork)

        if reservation.ip.nil? && reservation.is_a?(DynamicNetworkReservation)
          @logger.debug("Allocating dynamic ip for manual network '#{reservation.network.name}'")

          filter_subnet_by_instance_az(reservation).each do |subnet|
            @logger.debug("Trying to allocate a dynamic IP in subnet'#{subnet.inspect}'")
            ip = @ip_repo.get_dynamic_ip(subnet)
            if ip
              @logger.debug("Reserving dynamic IP '#{format_ip(ip)}' for manual network '#{reservation.network.name}'")
              @ip_repo.add(ip, subnet)
              reservation.resolve_ip(ip)
              reservation.mark_reserved_as(DynamicNetworkReservation)
              return
            end
          end
        end

        if reservation.ip
          cidr_ip = format_ip(reservation.ip)
          @logger.debug("Reserving #{reservation.desc} for manual network '#{reservation.network.name}'")

          subnet = find_subnet_containing(reservation)
          if subnet && subnet.static_ips.include?(reservation.ip.to_i)
            @ip_repo.add(reservation.ip, subnet)
            reservation.mark_reserved_as(StaticNetworkReservation)
            @logger.debug("Found subnet for #{format_ip(reservation.ip)}. Reserved as static network reservation.")
            return
          elsif subnet && subnet.restricted_ips.include?(reservation.ip.to_i) && reservation.is_a?(ExistingNetworkReservation)
            # FIXME: stop trying to reserve existing reservations. do something better.
            return
          elsif subnet
            @ip_repo.add(reservation.ip, subnet)
            reservation.mark_reserved_as(DynamicNetworkReservation)
            @logger.debug("Found subnet for #{format_ip(reservation.ip)}. Reserved as dynamic network reservation.")
            return
          end

          if reservation.is_a?(ExistingNetworkReservation)
            @logger.debug("Couldn't find subnet containing existing network reservation for #{format_ip(reservation.ip)}. No longer reserved.")
            return
          end

          raise NetworkReservationIpOutsideSubnet,
            "Provided static IP '#{cidr_ip}' does not belong to any subnet in network '#{reservation.network.name}'"
        end

        raise NetworkReservationNotEnoughCapacity,
          "Failed to reserve IP for '#{reservation.instance}' for manual network '#{reservation.network.name}': no more available"
      end

      private

      def filter_subnet_by_instance_az(reservation)
        instance_az = reservation.instance.availability_zone
        if instance_az.nil?
          reservation.network.subnets
        else
          reservation.network.subnets.select do |subnet|
            subnet.availability_zone == instance_az.name
          end
        end
      end

      def find_subnet_containing(reservation)
        reservation.network.subnets.find { |subnet| subnet.range.contains?(reservation.ip) }
      end
    end
  end
end
