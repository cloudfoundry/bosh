module Bosh::Director
  module DeploymentPlan
    class IpProvider
      include IpUtil

      def initialize(ip_repo, networks, logger)
        @logger = Bosh::Director::TaggedLogger.new(logger, 'network-configuration')
        @ip_repo = ip_repo
        @networks = networks
      end

      def release(reservation)
        if reservation.ip.nil?
          return if reservation.network.is_a?(DynamicNetwork)

          @logger.error("Failed to release IP for manual network '#{reservation.network.name}': IP must be provided")
          raise Bosh::Director::NetworkReservationIpMissing, "Can't release reservation without an IP"
        else
          @ip_repo.delete(reservation.ip)
        end
      end

      def reserve(reservation)

        if reservation.network.is_a?(DynamicNetwork)
          reserve_dynamic(reservation)
          return
        end

        if reservation.network.is_a?(VipNetwork)
          reserve_vip(reservation)
          return
        end

        if reservation.network.is_a?(ManualNetwork)
          reserve_manual(reservation)
          return
        end

        raise 'Unknown Network Type'
      end

      def reserve_existing_ips(reservation)
        case reservation.network

        when DynamicNetwork
          # Marking reservation as "reserved" so that it keeps existing reservation and
          # does not recreate VM

          reserve_dynamic(reservation) if reservation.network_type == 'dynamic'
          # If previous network type was not dynamic we should release reservation from DB
        when VipNetwork
          reserve_vip(reservation)
        when ManualNetwork
          subnet = reservation.network.subnets.find { |snet| snet.is_reservable?(reservation.ip) }

          reserve_manual_with_subnet(reservation, subnet) if subnet
        end
      end

      private

      def reserve_manual(reservation)
        if reservation.ip.nil?
          @logger.debug("Allocating dynamic ip for manual network '#{reservation.network.name}'")

          filter_subnet_by_instance_az(reservation).each do |subnet|
            if (ip = @ip_repo.allocate_dynamic_ip(reservation, subnet))
              @logger.debug("Reserving dynamic IP '#{ip}' for manual network '#{reservation.network.name}'")
              reservation.resolve_ip(ip)
              reservation.resolve_type(:dynamic)
              break
            end
          end

          if reservation.ip.nil?
            raise NetworkReservationNotEnoughCapacity,
              "Failed to reserve IP for '#{reservation.instance_model}' for manual network '#{reservation.network.name}': no more available"
          end
        else
          @logger.debug("Reserving #{reservation.desc} for manual network '#{reservation.network.name}'")

          if (subnet = reservation.network.find_subnet_containing(reservation.ip))
            if ip_in_array?(reservation.ip, subnet.restricted_ips)
              message = "Failed to reserve IP '#{reservation.ip}' for network '#{subnet.network_name}': IP belongs to reserved range"
              @logger.error(message)
              raise Bosh::Director::NetworkReservationIpReserved, message
            end

            reserve_manual_with_subnet(reservation, subnet)
          else
            raise NetworkReservationIpOutsideSubnet,
              "Provided static IP '#{reservation.ip}' does not belong to any subnet in network '#{reservation.network.name}'"
          end
        end
      end

      def reserve_manual_with_subnet(reservation, subnet)
        @ip_repo.add(reservation)

        subnet_az_names = subnet.availability_zone_names.to_a.join(', ')

        if ip_in_array?(reservation.ip, subnet.static_ips)
          reservation.resolve_type(:static)
          @logger.debug("Found subnet with azs '#{subnet_az_names}' for #{reservation.ip}. Reserved as static network reservation.")
        else
          reservation.resolve_type(:dynamic)
          @logger.debug("Found subnet with azs '#{subnet_az_names}' for #{reservation.ip}. Reserved as dynamic network reservation.")
        end
      end

      def reserve_vip(reservation)
        if reservation.network.globally_allocate_ip?
          if reservation.ip.nil?
            ip = nil

            filter_subnet_by_instance_az(reservation).each do |subnet|
              ip = @ip_repo.allocate_vip_ip(reservation, subnet)
              break if ip
            end

            if ip.nil?
              raise(
                NetworkReservationNotEnoughCapacity,
                "Failed to reserve IP for '#{reservation.instance_model}'" \
                " for vip network '#{reservation.network.name}': no more available",
              )
            end

            reservation.resolve_ip(ip)
          else
            @ip_repo.add(reservation)
          end

          reservation.resolve_type(:dynamic)
        else
          @ip_repo.add(reservation)
          reservation.resolve_type(:static)
        end
      end

      def reserve_dynamic(reservation)
        reservation.resolve_type(:dynamic)
      end

      def filter_subnet_by_instance_az(reservation)
        instance_az_name = reservation.instance_model.availability_zone
        if instance_az_name.nil?
          reservation.network.subnets
        else
          reservation.network.subnets.select do |subnet|
            subnet.availability_zone_names.include?(instance_az_name)
          end
        end
      end
    end
  end
end
