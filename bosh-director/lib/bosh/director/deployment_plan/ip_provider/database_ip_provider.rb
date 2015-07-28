module Bosh::Director::DeploymentPlan
  class DatabaseIpProvider
    include Bosh::Director::IpUtil
    class OutsideRangeError < StandardError; end
    class IPAlreadyReserved < StandardError; end
    class IPOwnedByOtherDeployment < StandardError; end

    # @param [NetAddr::CIDR] range
    # @param [String] network_name
    def initialize(deployment_model, range, network_name, restricted_ips, static_ips, logger)
      @deployment_model = deployment_model
      @range = range
      @network_name = network_name
      @network_desc = "network '#{@network_name}' (#{@range})"
      @restricted_ips = restricted_ips
      @static_ips = static_ips
      @logger = Bosh::Director::TaggedLogger.new(logger, 'network-configuration', 'database-ip-provider')
    end

    # @return [NetAddr::CIDR] ip
    def allocate_dynamic_ip
      begin
        ip_address = try_to_allocate_dynamic_ip
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

    # @param [NetAddr::CIDR] ip
    def reserve_ip(ip)
      cidr_ip = CIDRIP.new(ip)
      if @restricted_ips.include?(cidr_ip.to_i)
        @logger.error("Failed to reserve ip '#{cidr_ip}' for #{@network_desc}: IP belongs to reserved range")
        return nil
      end

      begin
        reserve_with_deployment_validation(cidr_ip)
      rescue IPOwnedByOtherDeployment
        @logger.error("Failed to reserve ip '#{cidr_ip}' for #{@network_desc}: IP is reserved by another deployment")
        return nil
      end

      if @static_ips.include?(cidr_ip.to_i)
        @logger.debug("Reserved static ip '#{cidr_ip}' for #{@network_desc}")
        :static
      else
        @logger.debug("Reserved dynamic ip '#{cidr_ip}' for #{@network_desc}")
        :dynamic
      end
    end

    # @param [NetAddr::CIDR] ip or [Integer] ip
    def release_ip(ip)
      cidr_ip = CIDRIP.new(ip)

      ip_address = Bosh::Director::Models::IpAddress.first(
        address: cidr_ip.to_i,
        network_name: @network_name,
      )

      unless ip_address
        @logger.debug("Failed to release ip '#{cidr_ip}' for #{@network_desc}: IP is reserved by another deployment")
        raise Bosh::Director::NetworkReservationIpNotOwned,
          "Can't release IP '#{cidr_ip}' " +
            "back to network '#{@network_name}': " +
            "it's neither in dynamic nor in static pool"
      end

      @logger.debug("Releasing ip '#{cidr_ip}'")
      ip_address.destroy
    end

    private

    def try_to_allocate_dynamic_ip
      addrs = Set.new(network_addresses)
      addrs << @range.first(Objectify: true).to_i - 1 if addrs.empty?

      addrs.merge(@restricted_ips.to_a) unless @restricted_ips.empty?
      addrs.merge(@static_ips.to_a) unless @static_ips.empty?

      # find address that doesn't have subsequent address
      addr = addrs.to_a.sort.find { |a| !addrs.include?(a+1) }
      ip_address = NetAddr::CIDRv4.new(addr+1)

      unless @range == ip_address || @range.contains?(ip_address)
        raise OutsideRangeError
      end

      save_ip(ip_address)

      ip_address
    end

    def network_addresses
      Bosh::Director::Models::IpAddress.select(:address)
        .where(network_name: @network_name).all.map { |a| a.address }
    end

    # @param [NetAddr::CIDR] ip
    def reserve_with_deployment_validation(ip)
      # try to save IP first before validating it's deployment to prevent race conditions
      save_ip(ip)
    rescue IPAlreadyReserved
      ip_address = Bosh::Director::Models::IpAddress.first(
        address: ip.to_i,
        network_name: @network_name,
      )

      if ip_address
        if ip_address.deployment == @deployment_model
          return ip_address
        else
          raise IPOwnedByOtherDeployment
        end
      end
    end

    # @param [NetAddr::CIDR] ip
    def save_ip(ip)
      Bosh::Director::Models::IpAddress.new(
        address: ip.to_i,
        network_name: @network_name,
        deployment: @deployment_model,
        task_id: Bosh::Director::Config.current_job.task_id
      ).save
    rescue Sequel::DatabaseError
      raise IPAlreadyReserved
    end
  end
end
