module Bosh::Director::DeploymentPlan
  class IpRepo
    include Bosh::Director::IpUtil
    class IpFoundInDatabaseAndCanBeRetried < StandardError; end
    class NoMoreIPsAvailableAndStopRetrying < StandardError; end
    class PrefixOutOfRange < StandardError; end

    def initialize(logger)
      @logger = Bosh::Director::TaggedLogger.new(logger, 'network-configuration')
    end

    def delete(ip)
      ip_or_cidr = to_ipaddr(ip)

      ip_address = Bosh::Director::Models::IpAddress.first(address_str: ip_or_cidr.to_s)

      if ip_address
        @logger.debug("Releasing ip '#{ip_or_cidr}'")
        ip_address.destroy
      else
        @logger.debug("Skipping releasing ip '#{ip_or_cidr}': not reserved")
      end
    end

    def add(reservation)
      ip_or_cidr = reservation.ip

      reservation_type = reservation.network.ip_type(ip_or_cidr)

      reserve_with_instance_validation(
        reservation.instance_model,
        ip_or_cidr,
        reservation,
        reservation_type.eql?(:static),
      )

      reservation.resolve_type(reservation_type)

      @logger.debug("Reserved ip '#{ip_or_cidr}' for #{reservation.network.name} as #{reservation_type}")
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

      @logger.debug("Allocated dynamic IP '#{ip_address}' for #{reservation.network.name}")
      ip_address
    end

    def allocate_vip_ip(reservation, subnet)
      begin
        ip_address = try_to_allocate_vip_ip(reservation, subnet)
      rescue NoMoreIPsAvailableAndStopRetrying
        @logger.debug('Failed to allocate vip ip: no more available')
        return nil
      rescue IpFoundInDatabaseAndCanBeRetried
        @logger.debug('Retrying to allocate vip ip: probably a race condition with another deployment')

        # IP can be taken by other deployment that runs in parallel
        # retry until succeeds or out of range
        retry
      end

      @logger.debug("Allocated vip IP '#{ip_address}' for #{reservation.network.name}")
      ip_address
    end

    private

    def all_ip_addresses
      Bosh::Director::Models::IpAddress.select(:address_str).all.map { |a| a.address }
    end

    def try_to_allocate_dynamic_ip(reservation, subnet)
      addresses_in_use = Set.new(all_ip_addresses)

      first_range_address = to_ipaddr(subnet.range.to_range.first.to_i - 1)

      addresses_we_cant_allocate = addresses_in_use

      addresses_we_cant_allocate.merge(subnet.restricted_ips) unless subnet.restricted_ips.empty?
      addresses_we_cant_allocate.merge(subnet.static_ips) unless subnet.static_ips.empty?

      if subnet.range.ipv6?
        addresses_we_cant_allocate.delete_if { |ipaddr| ipaddr.ipv4? }
      else
        addresses_we_cant_allocate.delete_if { |ipaddr| ipaddr.ipv6? }
      end

      # Sort by address first, then by prefix (smaller prefix = larger block = earlier)
      uniq_ips = addresses_we_cant_allocate.uniq
      sorted_ips = uniq_ips.sort_by { |ip| [ip.to_i, ip.prefix] }

      # Remove IPs contained within larger CIDR blocks
      sorted_ips = sorted_ips.reject.with_index do |ip, index|
        sorted_ips[0...index].any? do |other_ip|
          other_ip.prefix < ip.prefix && other_ip.include?(ip)
        rescue StandardError
          false
        end
      end

      ip_address_cidr = find_next_available_ip(sorted_ips, first_range_address, subnet.prefix)

      unless subnet.range == ip_address_cidr || subnet.range.include?(ip_address_cidr)
        raise NoMoreIPsAvailableAndStopRetrying
      end

      save_ip(ip_address_cidr, reservation, false)

      ip_address_cidr
    end

    def find_next_available_ip(sorted_blocking_ips, first_range_address, prefix)
      # Remove IPs that are below subnet range
      filtered_ips = sorted_blocking_ips.reject { |ip| ip.to_i < first_range_address.to_i }

      current_ip = to_ipaddr(first_range_address.to_i + 1)

      loop do
        current_prefix = to_ipaddr("#{current_ip.base_addr}/#{prefix}")

        # Check both directions for overlap: candidate includes blocking IP, or blocking IP includes candidate
        blocking_ip = filtered_ips.find do |ip|
          (current_prefix.include?(ip) rescue false) ||
          (ip.include?(current_prefix) rescue false)
        end

        return current_prefix if blocking_ip.nil?

        if blocking_ip.count > current_prefix.count
          # Blocking range is larger, skip past its entire range
          current_ip = to_ipaddr(blocking_ip.to_i + blocking_ip.count)
        else
          # Blocking IP is smaller or same size, try next aligned position
          current_ip = to_ipaddr(current_prefix.to_i + current_prefix.count)
        end

        # Clean up blocking IPs that we've passed
        filtered_ips.reject! { |ip| ip.to_i + ip.count <= current_ip.to_i }
      end
    end

    def try_to_allocate_vip_ip(reservation, subnet)
      addresses_in_use = Set.new(all_ip_addresses.map { |ip| ip.to_i })

      if to_ipaddr(subnet.static_ips.first.to_i).ipv6?
        prefix = Bosh::Director::DeploymentPlan::Network::IPV6_DEFAULT_PREFIX_SIZE
      else
        prefix = Bosh::Director::DeploymentPlan::Network::IPV4_DEFAULT_PREFIX_SIZE
      end

      available_ips = subnet.static_ips.map(&:to_i).to_set - addresses_in_use

      raise NoMoreIPsAvailableAndStopRetrying if available_ips.empty?

      ip_address = to_ipaddr("#{to_ipaddr(available_ips.first).base_addr}/#{prefix}")

      save_ip(ip_address, reservation, false)

      ip_address
    end

    def reserve_with_instance_validation(instance_model, ip, reservation, is_static)
      # try to save IP first before validating its instance to prevent race conditions
      save_ip(ip, reservation, is_static)
    rescue IpFoundInDatabaseAndCanBeRetried
      ip_address = Bosh::Director::Models::IpAddress.first(address_str: ip.to_s)

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

        ip_address
      elsif reserved_instance.nil?
        raise Bosh::Director::NetworkReservationAlreadyInUse,
              "Failed to reserve IP '#{ip}' for instance '#{instance_model}': " \
              'already reserved by orphaned instance'
      else
        raise Bosh::Director::NetworkReservationAlreadyInUse,
              "Failed to reserve IP '#{ip}' for instance '#{instance_model}': " \
              "already reserved by instance '#{reserved_instance.name}' " \
              "from deployment '#{reserved_instance.deployment.name}'"
      end
    end

    def save_ip(ip, reservation, is_static)
      @logger.debug("Adding IP Address: #{ip} from reservation: #{reservation}")
      ip_address = Bosh::Director::Models::IpAddress.new(
        address_str: ip.to_s,
        network_name: reservation.network.name,
        task_id: Bosh::Director::Config.current_job.task_id,
        static: is_static,
        nic_group: reservation.nic_group,
        )
      reservation.instance_model.add_ip_address(ip_address)
    rescue Sequel::ValidationFailed, Sequel::DatabaseError => e
      error_message = e.message.downcase
      if error_message.include?('unique') || error_message.include?('duplicate')
        raise IpFoundInDatabaseAndCanBeRetried, e.inspect
      else
        raise e
      end
    end
  end
end
