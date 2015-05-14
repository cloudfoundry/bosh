require 'bosh/director/deployment_plan/job_spec_parser'
require 'bosh/template/property_helper'

module Bosh::Director::DeploymentPlan
  class DatabaseIpProvider
    include Bosh::Director::IpUtil

    # @param [NetAddr::CIDR] range
    # @param [String] network_name
    def initialize(range, network_name)
      @range = range
      @network_name = network_name
      blacklist_ip(@range.network(:Objectify => true))
    end

    # @return [Integer] ip
    def allocate_dynamic_ip
      # find address that doesn't have subsequent address
      address_without_following = Bosh::Director::Models::IpAddress.select(:address).
        where(network_name: @network_name).
        exclude(address: Bosh::Director::Models::IpAddress.select(:address - 1)).
        order(:address).
        limit(1).
        first

      if address_without_following
        ip_address = NetAddr::CIDRv4.new(address_without_following.address + 1)
        return nil unless @range.contains?(ip_address)
      else
        ip_address = @range.first(Objectify: true)
      end

      return nil unless reserve_with_type(ip_address, 'dynamic')

      ip_address.to_i
    end

    # @param [NetAddr::CIDR] ip
    def reserve_ip(ip)
      if reserve_static(ip)
        :static
      else
        reserve_with_type(ip, 'dynamic') ? :dynamic : nil
      end
    end

    # @param [NetAddr::CIDR] ip
    def release_ip(ip)
      ip_address = Bosh::Director::Models::IpAddress.exclude(type: 'reserved').first(
        address: ip.to_i,
        network_name: @network_name,
      )

      unless ip_address
        raise Bosh::Director::NetworkReservationIpNotOwned,
          "Can't release IP `#{format_ip(ip)}' " +
            "back to `#{@network_name}' network: " +
            "it's neither in dynamic nor in static pool"
      end

      ip_address.destroy
    end

    # @param [NetAddr::CIDR] ip
    def blacklist_ip(ip)
      unless @range.contains?(NetAddr::CIDRv4.new(ip.to_i))
        raise Bosh::Director::NetworkReservedIpOutOfRange,
          "Reserved IP `#{format_ip(ip)}' is out of " +
            "network `#{@network_name}' range"
      end
      reserve_with_type(ip, 'reserved')
    end

    # @param [NetAddr::CIDR] ip
    def add_static_ip(ip)
      unless @range.contains?(NetAddr::CIDRv4.new(ip.to_i))
        raise Bosh::Director::NetworkStaticIpOutOfRange,
          "Static IP `#{format_ip(ip)}' is out of " +
            "network `#{@network_name}' range"
      end
      reserve_with_type(ip, 'static', false)
    end

    private

    # @param [NetAddr::CIDR] ip
    # @param [String] type ['static', 'dynamic' or 'reserved']
    # @param [Boolean] allocated true if ip is allocated
    def reserve_with_type(ip, type, allocated = true)
      Bosh::Director::Models::IpAddress.new(
        address: ip.to_i,
        network_name: @network_name,
        type: type,
        allocated: allocated,
      ).save
    rescue Sequel::DatabaseError
      nil
    end

    # @param [NetAddr::CIDR] ip
    def reserve_static(ip)
      ip_address = Bosh::Director::Models::IpAddress.first(
        address: ip.to_i,
        network_name: @network_name,
        type: 'static',
        allocated: false,
      )
      return nil unless ip_address

      ip_address.allocated = true
      ip_address.save
    end
  end
end
