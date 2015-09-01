module Bosh::Director
  module DeploymentPlan
    class IpProviderV2
      include IpUtil

      def initialize(ip_repo, logger)
        @logger = logger
        @ip_repo = ip_repo
      end

      def release(reservation)
        return unless reservation.network.is_a?(ManualNetwork)

        # TODO: select the right subnet
        if reservation.ip.nil?
          @logger.error("Failed to release IP for manual network '#{reservation.network.name}': IP must be provided")
          raise Bosh::Director::NetworkReservationIpMissing, "Can't release reservation without an IP"
        else
          @ip_repo.delete(reservation.ip, reservation.network.subnets.first)
        end
      end

      def reserve(reservation)
        return unless reservation.network.is_a?(ManualNetwork)

        if reservation.ip.nil? && reservation.is_a?(DynamicNetworkReservation)
          @logger.debug("Allocating dynamic ip for manual network '#{reservation.network.name}'")

          filter_subnet_by_instance_az(reservation).each do |subnet|
            @logger.debug("Trying to allocate a dynamic IP in subnet'#{subnet.inspect}'")
            ip = subnet.allocate_dynamic_ip(reservation.instance)
            if ip
              @logger.debug("Reserving dynamic IP '#{format_ip(ip)}' for manual network '#{reservation.network.name}'")
              reservation.resolve_ip(ip)
              reservation.mark_reserved_as(DynamicNetworkReservation)
              return
            end
          end
        end

        if reservation.ip
          cidr_ip = format_ip(reservation.ip)
          @logger.debug("Reserving static ip '#{cidr_ip}' for manual network '#{reservation.network.name}'")

          subnet = find_subnet_containing(reservation)
          if subnet
            subnet.reserve_ip(reservation)
            @ip_repo.add(reservation.ip, reservation.network.subnets.first)
            return
          end

          if reservation.is_a?(ExistingNetworkReservation)
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
