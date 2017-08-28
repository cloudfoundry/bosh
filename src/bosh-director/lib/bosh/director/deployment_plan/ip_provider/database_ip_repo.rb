module Bosh::Director::DeploymentPlan
  class DatabaseIpRepo
    include Bosh::Director::IpUtil
    class IpFoundInDatabaseAndCanBeRetried < StandardError; end
    class NoMoreIPsAvailableAndStopRetrying < StandardError; end

    def initialize(logger)
      @logger = Bosh::Director::TaggedLogger.new(logger, 'network-configuration')
    end

    def delete(ip, _)
      cidr_ip = CIDRIP.new(ip)

      ip_address = Bosh::Director::Models::IpAddress.first(address_str: cidr_ip.to_i.to_s)

      if ip_address
        @logger.debug("Releasing ip '#{cidr_ip}'")
        ip_address.destroy
      else
        @logger.debug("Skipping releasing ip '#{cidr_ip}': not reserved")
      end
    end

    def add(reservation)
      cidr_ip = CIDRIP.new(reservation.ip)

      reservation_type = reservation.network.ip_type(cidr_ip)

      reserve_with_instance_validation(
        reservation.instance_model,
        cidr_ip,
        reservation,
        reservation_type.eql?(:static)
      )

      reservation.resolve_type(reservation_type)
      reservation.mark_reserved
      @logger.debug("Reserved ip '#{cidr_ip}' for #{reservation.network.name} as #{reservation_type}")
    end

    def allocate_dynamic_ip(reservation, subnet)
      begin
        ip_address = try_to_allocate_dynamic_ip(reservation, subnet)
      rescue NoMoreIPsAvailableAndStopRetrying
        @logger.debug('Failed to allocate dynamic ip: no more available')
        return nil
      rescue IpFoundInDatabaseAndCanBeRetried
        @logger.debug('Retrying to allocate dynamic ip: probably a race condition with another deployment')
        # IP can be taken by other deployment that runs in parallel
        # retry until succeeds or out of range
        retry
      end

      @logger.debug("Allocated dynamic IP '#{ip_address.ip}' for #{reservation.network.name}")
      ip_address.to_i
    end

    private

    def try_to_allocate_dynamic_ip(reservation, subnet)
      addresses_in_use = Set.new(all_ip_addresses)

      first_range_address = subnet.range.first(Objectify: true).to_i - 1
      addresses_we_cant_allocate = addresses_in_use
      addresses_we_cant_allocate << first_range_address

      addresses_we_cant_allocate.merge(subnet.restricted_ips.to_a) unless subnet.restricted_ips.empty?
      addresses_we_cant_allocate.merge(subnet.static_ips.to_a) unless subnet.static_ips.empty?
      # find first in-use address whose subsequent address is not in use
      # the subsequent address must be free
      addr = addresses_we_cant_allocate
               .to_a
               .reject {|a| a < first_range_address }
               .sort
               .find { |a| !addresses_we_cant_allocate.include?(a+1) }
      if subnet.range.version == 6
        ip_address = NetAddr::CIDRv6.new(addr+1)
      else
        ip_address = NetAddr::CIDRv4.new(addr+1)
      end

      unless subnet.range == ip_address || subnet.range.contains?(ip_address)
        raise NoMoreIPsAvailableAndStopRetrying
      end

      save_ip(ip_address, reservation, false)

      ip_address
    end

    def all_ip_addresses
      Bosh::Director::Models::IpAddress.select(:address_str).all.map { |a| a.address_str.to_i }
    end

    def reserve_with_instance_validation(instance_model, ip, reservation, is_static)
      # try to save IP first before validating its instance to prevent race conditions
      save_ip(ip, reservation, is_static)
    rescue IpFoundInDatabaseAndCanBeRetried
      ip_address = Bosh::Director::Models::IpAddress.first(address_str: ip.to_i.to_s)

      retry unless ip_address

      validate_instance_and_update_reservation_type(instance_model, ip, ip_address, reservation.network.name, is_static)
    end

    def validate_instance_and_update_reservation_type(instance_model, ip, ip_address, network_name, is_static)
      reserved_instance = ip_address.instance
      if reserved_instance == instance_model
        if ip_address.static != is_static || ip_address.network_name != network_name
          reservation_type = is_static ? 'static' : 'dynamic'
          @logger.debug("Updating reservation for ip '#{ip}' with type '#{reservation_type}' and network '#{network_name}'")
          ip_address.update(static: is_static, network_name: network_name)
        end

        return ip_address
      else
        raise Bosh::Director::NetworkReservationAlreadyInUse,
          "Failed to reserve IP '#{ip}' for instance '#{instance_model}': " +
            "already reserved by instance '#{reserved_instance.name}' " +
            "from deployment '#{reserved_instance.deployment.name}'"
      end
    end

    def save_ip(ip, reservation, is_static)
      reservation.instance_model.add_ip_address(
        address_str: ip.to_i.to_s,
        network_name: reservation.network.name,
        task_id: Bosh::Director::Config.current_job.task_id,
        static: is_static
      )
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
