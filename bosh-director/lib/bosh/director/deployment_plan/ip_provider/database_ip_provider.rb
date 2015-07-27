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
      @restricted_ips = restricted_ips
      @static_ips = static_ips
      @logger = logger
      @log_tag = '[ip-reservation][database-ip-provider]'
    end

    # @return [Integer] ip
    def allocate_dynamic_ip
      begin
        ip_address = try_to_allocate_dynamic_ip
      rescue OutsideRangeError
        @logger.debug("#{@log_tag} Failed to allocate dynamic ip: no more available")
        return nil
      rescue IPAlreadyReserved
        @logger.debug("#{@log_tag} Retrying to allocate dynamic ip: probably a race condition with another deployment")
        # IP can be taken by other deployment that runs in parallel
        # retry until succeeds or out of range
        retry
      end

      @logger.debug("#{@log_tag} Allocating dynamic ip '#{ip_address}'")
      ip_address.to_i
    end

    # @param [NetAddr::CIDR] ip
    def reserve_ip(ip)
      if @restricted_ips.include?(ip.to_i)
        @logger.error("#{@log_tag} Failed to reserve ip '#{ip}': IP belongs to reserved range")
        return nil
      end

      begin
        reserve_with_deployment_validation(ip)
      rescue IPOwnedByOtherDeployment
        @logger.error("#{@log_tag} Failed to reserve ip '#{ip}': IP is reserved by another deployment")
        return nil
      end

      if @static_ips.include?(ip.to_i)
        @logger.debug("#{@log_tag} Reserved static ip '#{ip}'")
        :static
      else
        @logger.debug("#{@log_tag} Reserved dynamic ip '#{ip}'")
        :dynamic
      end
    end

    # @param [NetAddr::CIDR] ip
    def release_ip(ip)
      ip_address = Bosh::Director::Models::IpAddress.first(
        address: ip.to_i,
        network_name: @network_name,
      )

      unless ip_address
        @logger.debug("#{@log_tag} Failed to release ip '#{ip}': IP is reserved by another deployment")
        raise Bosh::Director::NetworkReservationIpNotOwned,
          "Can't release IP `#{format_ip(ip)}' " +
            "back to `#{@network_name}' network: " +
            "it's neither in dynamic nor in static pool"
      end

      @logger.debug("#{@log_tag} Releasing ip '#{ip}'")
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
