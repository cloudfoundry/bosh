module Bosh::Director
  module DeploymentPlan
    class IpProviderV2
      include IpUtil

      def initialize(ip_repo, vip_repo, using_global_networking, logger)
        @logger = logger
        @ip_repo = ip_repo
        @using_global_networking = using_global_networking
        @vip_repo = vip_repo
      end

      def release(reservation)
        return if reservation.network.is_a?(DynamicNetwork)

        if reservation.ip.nil?
          @logger.error("Failed to release IP for manual network '#{reservation.network.name}': IP must be provided")
          raise Bosh::Director::NetworkReservationIpMissing, "Can't release reservation without an IP"
        else
          ip_repo = reservation.network.is_a?(VipNetwork) ? @vip_repo : @ip_repo
          ip_repo.delete(reservation.ip, reservation.network.name)
        end
      end

      def reserve(reservation)
        return if reservation.network.is_a?(DynamicNetwork)

        if reservation.network.is_a?(VipNetwork)
          reservation.validate_type(StaticNetworkReservation)

          @logger.debug("Reserving IP '#{format_ip(reservation.ip)}' for vip network '#{reservation.network.name}'")
          #FIXME: We keep track of VIP Networks in-memory only
          @vip_repo.add(reservation)
          reservation.mark_reserved_as(StaticNetworkReservation)
          return
        end

        if reservation.ip.nil?
          if reservation.is_a?(DynamicNetworkReservation)
            @logger.debug("Allocating dynamic ip for manual network '#{reservation.network.name}'")

            filter_subnet_by_instance_az(reservation).each do |subnet|
              @logger.debug("Trying to allocate a dynamic IP in subnet'#{subnet.inspect}'")
              if @using_global_networking
                ip = @ip_repo.allocate_dynamic_ip(reservation, subnet)
                if ip
                  @logger.debug("Reserving dynamic IP '#{format_ip(ip)}' for manual network '#{reservation.network.name}'")
                  reservation.resolve_ip(ip)
                  reservation.mark_reserved_as(DynamicNetworkReservation)
                  return
                end
              else
                ip = @ip_repo.get_dynamic_ip(subnet)
                if ip
                  @logger.debug("Reserving dynamic IP '#{format_ip(ip)}' for manual network '#{reservation.network.name}'")

                  reservation.resolve_ip(ip)
                  @ip_repo.add(reservation)
                  reservation.mark_reserved_as(DynamicNetworkReservation)
                  return
                end
              end
            end

            raise NetworkReservationNotEnoughCapacity,
              "Failed to reserve IP for '#{reservation.instance}' for manual network '#{reservation.network.name}': no more available"
          else
            # TODO: is this case even possible?
          end
        end

        if reservation.ip
          cidr_ip = format_ip(reservation.ip)
          @logger.debug("Reserving #{reservation.desc} for manual network '#{reservation.network.name}'")

          subnet = find_subnet_containing(reservation)

          if subnet
            if subnet.restricted_ips.include?(reservation.ip.to_i)
              if reservation.is_a?(ExistingNetworkReservation)
                # FIXME: stop trying to reserve existing reservations. do something better.
                # for now we just make sure to not mark it as reserved
                return
              else
                message = "Failed to reserve IP '#{format_ip(reservation.ip)}' for network '#{subnet.network.name}': IP belongs to reserved range"
                @logger.error(message)
                raise Bosh::Director::NetworkReservationIpReserved, message
              end
            end

            if subnet.static_ips.include?(reservation.ip.to_i)
              @ip_repo.add(reservation)
              reservation.mark_reserved_as(StaticNetworkReservation)
              @logger.debug("Found subnet for #{format_ip(reservation.ip)}. Reserved as static network reservation.")
              return
            else
              @ip_repo.add(reservation)
              reservation.mark_reserved_as(DynamicNetworkReservation)
              @logger.debug("Found subnet for #{format_ip(reservation.ip)}. Reserved as dynamic network reservation.")
              return
            end
          else
            if reservation.is_a?(ExistingNetworkReservation)
              @logger.debug("Couldn't find subnet containing existing network reservation for #{format_ip(reservation.ip)}. No longer reserved.")
              return
            else
              raise NetworkReservationIpOutsideSubnet,
                "Provided static IP '#{cidr_ip}' does not belong to any subnet in network '#{reservation.network.name}'"
            end
          end
        end
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
