require 'bosh/director/deployment_plan/job_spec_parser'
require 'bosh/template/property_helper'

module Bosh::Director::DeploymentPlan
  class IpProvider
    include Bosh::Director::IpUtil

    # @param [NetAddr::CIDR] range
    # @param [String] network_name
    def initialize(range, network_name)
      @range = range
      @network_name = network_name
    end

    # @return [Integer] IpAddress
    def allocate_dynamic_ip
      decremented_addresses = Bosh::Director::Models::IpAddress.
        where(network_name: @network_name).
        select_map{ address - 1 }

      # find address that don't have following address
      address_without_following = Bosh::Director::Models::IpAddress.select(:address).
        where(network_name: @network_name).
        exclude(address: decremented_addresses).order(:address).limit(1).first

      if address_without_following
        ip_address = NetAddr::CIDRv4.new(address_without_following.address + 1)
        return nil unless @range.contains?(ip_address)
      else
        ip_address = @range.first(Objectify: true)
      end

      return nil unless reserve_ip(ip_address)

      ip_address.to_i
    end

    # @param [NetAddr::CIDR] ip
    def reserve_ip(ip)
      Bosh::Director::Models::IpAddress.new(
        address: ip.to_i,
        network_name: @network_name,
      ).save
    rescue Sequel::DatabaseError
      nil
    end

    # @param [NetAddr::CIDR] ip
    def release_ip(ip)
      ip_address = Bosh::Director::Models::IpAddress.first(
        address: ip.to_i,
        network_name: @network_name,
      )

      unless ip_address
        raise Bosh::Director::NetworkReservationIpNotOwned,
          "Can't release IP `#{format_ip(ip)}' " +
            "back to `#{@network_name}' network: " +
            "it's not in the pool of reserved ips"
      end

      ip_address.destroy
    end
  end
end
