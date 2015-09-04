module Bosh::Director::DeploymentPlan
  class DatabaseIpRepo
    include Bosh::Director::IpUtil
    class IpFoundInDatabaseAndCanBeRetried < StandardError;
    end

    def initialize(logger)
      @logger = logger
    end

    def delete(ip, network_name)
      cidr_ip = CIDRIP.new(ip)

      ip_address = Bosh::Director::Models::IpAddress.first(
        address: cidr_ip.to_i,
        network_name: network_name,
      )

      if ip_address
        @logger.debug("Releasing ip '#{cidr_ip}'")
        ip_address.destroy
      else
        @logger.debug("Skipping releasing ip '#{cidr_ip}' for #{network_name}: not reserved")
      end
    end

    def add(reservation)
      cidr_ip = CIDRIP.new(reservation.ip)

      static_ips = reservation.network.subnets
                     .map { |subnet| subnet.static_ips.to_a }
                     .flatten

      if static_ips.include?(cidr_ip.to_i)
        reservation_type = Bosh::Director::StaticNetworkReservation
      else
        reservation_type = Bosh::Director::DynamicNetworkReservation
      end
      reserve_with_instance_validation(
        reservation.instance,
        cidr_ip,
        reservation,
        reservation_type.eql?(Bosh::Director::StaticNetworkReservation)
      )

      reservation.mark_reserved_as(reservation_type)
      @logger.debug("Reserved ip '#{cidr_ip}' for #{reservation.network.name} as #{reservation_type}")
    end

    private
    def reserve_with_instance_validation(instance, ip, reservation, is_static)
      # try to save IP first before validating it's instance to prevent race conditions
      save_ip(instance, ip, reservation, is_static)
    rescue IpFoundInDatabaseAndCanBeRetried
      ip_address = Bosh::Director::Models::IpAddress.first(
        address: ip.to_i,
        network_name: reservation.network.name,
      )

      retry unless ip_address

      validate_instance_and_update_reservation_type(instance, ip, ip_address, is_static)
    end

    def validate_instance_and_update_reservation_type(instance, ip, ip_address, is_static)
      reserved_instance = ip_address.instance
      if reserved_instance == instance.model
        if ip_address.static != is_static
          reservation_type = is_static ? 'static' : 'dynamic'
          @logger.debug("Switching reservation type of IP: '#{ip}' to #{reservation_type}")
          ip_address.update(static: is_static)
        end

        return ip_address
      else
        raise Bosh::Director::NetworkReservationAlreadyInUse,
          "Failed to reserve IP '#{ip}' for instance '#{instance}': " +
            "already reserved by instance '#{reserved_instance.job}/#{reserved_instance.index}' " +
            "from deployment '#{reserved_instance.deployment.name}'"
      end
    end

    def save_ip(instance, ip, reservation, is_static)
      Bosh::Director::Models::IpAddress.new(
        address: ip.to_i,
        network_name: reservation.network.name,
        instance: instance.model,
        task_id: Bosh::Director::Config.current_job.task_id,
        static: is_static
      ).save
    rescue Sequel::ValidationFailed, Sequel::DatabaseError => e
      error_message = e.message.downcase
      if error_message.include?('unique') || error_message.include?('duplicate')
        raise IpFoundInDatabaseAndCanBeRetried
      else
        raise e
      end
    end
  end
end
