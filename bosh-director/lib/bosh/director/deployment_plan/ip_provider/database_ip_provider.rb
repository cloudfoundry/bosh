module Bosh::Director::DeploymentPlan
  class DatabaseIpProvider
    include Bosh::Director::IpUtil
    class OutsideRangeError < StandardError; end
    class IPAlreadyReserved < StandardError; end

    # @param [NetAddr::CIDR] range
    # @param [String] network_name
    def initialize(range, network_name, restricted_ips, static_ips, logger)
      @range = range
      @network_name = network_name
      @network_desc = "network '#{@network_name}' (#{@range})"
      @restricted_ips = restricted_ips
      @static_ips = static_ips
      @logger = Bosh::Director::TaggedLogger.new(logger, 'network-configuration', 'database-ip-provider')
    end

    # @return [NetAddr::CIDR] ip
    def allocate_dynamic_ip(instance)
      begin
        ip_address = try_to_allocate_dynamic_ip(instance)
      rescue OutsideRangeError
        @logger.debug("Failed to allocate dynamic ip: no more available")
        return nil
      rescue IPAlreadyReserved
        @logger.debug("Retrying to allocate dynamic ip: probably a race condition with another deployment")
        # IP can be taken by other deployment that runs in parallel
        # retry until succeeds or out of range
        retry
      end

      @logger.debug("Allocated dynamic IP '#{ip_address.ip}' for #{@network_desc}")
      ip_address.to_i
    end

    # @param [NetworkReservation] reservation
    def reserve_ip(reservation)
      cidr_ip = CIDRIP.new(reservation.ip)
      if @restricted_ips.include?(cidr_ip.to_i)
        return if reservation.is_a?(Bosh::Director::ExistingNetworkReservation)
        message = "Failed to reserve IP '#{cidr_ip}' for network '#{@network_name}': IP belongs to reserved range"
        @logger.error(message)
        raise Bosh::Director::NetworkReservationIpReserved, message
      end

      if @static_ips.include?(cidr_ip.to_i)
        reservation_type = Bosh::Director::StaticNetworkReservation
      else
        reservation_type = Bosh::Director::DynamicNetworkReservation
      end

      reserve_with_instance_validation(
        reservation.instance,
        cidr_ip,
        reservation_type.eql?(Bosh::Director::StaticNetworkReservation)
      )

      reservation.mark_reserved_as(reservation_type)
      @logger.debug("Reserved ip '#{cidr_ip}' for #{@network_desc} as #{reservation_type}")
    end

    private

    def try_to_allocate_dynamic_ip(instance)
      addrs = Set.new(network_addresses)
      first_range_address = @range.first(Objectify: true).to_i - 1
      addrs << first_range_address

      addrs.merge(@restricted_ips.to_a) unless @restricted_ips.empty?
      addrs.merge(@static_ips.to_a) unless @static_ips.empty?

      # find first address that doesn't have subsequent address
      addr = addrs.to_a.reject {|a| a < first_range_address }.sort.find { |a| !addrs.include?(a+1) }
      ip_address = NetAddr::CIDRv4.new(addr+1)

      unless @range == ip_address || @range.contains?(ip_address)
        raise OutsideRangeError
      end

      save_ip(instance, ip_address, false)

      ip_address
    end

    def network_addresses
      Bosh::Director::Models::IpAddress.select(:address)
        .where(network_name: @network_name).all.map { |a| a.address }
    end

    # @param [NetAddr::CIDR] ip
    def reserve_with_instance_validation(instance, ip, is_static)
      # try to save IP first before validating it's instance to prevent race conditions
      save_ip(instance, ip, is_static)
    rescue IPAlreadyReserved
      ip_address = Bosh::Director::Models::IpAddress.first(
        address: ip.to_i,
        network_name: @network_name,
      )

      retry unless ip_address

      validate_instance_and_update_reservation_type(instance, ip, ip_address, is_static)
    end

    def validate_instance_and_update_reservation_type(instance, ip, ip_address, is_static)
      reserved_instance = ip_address.instance
      if reserved_instance == instance.model
        if ip_address.static != is_static
          log_ip_type = is_static ? 'static' : 'dynamic'
          @logger.debug("Switching reservation type of IP: '#{ip}' to #{log_ip_type}")
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

    # @param [NetAddr::CIDR] ip
    def save_ip(instance, ip, is_static)
      Bosh::Director::Models::IpAddress.new(
        address: ip.to_i,
        network_name: @network_name,
        instance: instance.model,
        task_id: Bosh::Director::Config.current_job.task_id,
        static: is_static
      ).save
    rescue Sequel::ValidationFailed, Sequel::DatabaseError => e
      error_message = e.message.downcase
      if error_message.include?('unique') || error_message.include?('duplicate')
        raise IPAlreadyReserved
      else
        raise e
      end
    end
  end
end
