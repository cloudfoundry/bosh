require 'bosh/director/deployment_plan/job_spec_parser'
require 'bosh/template/property_helper'

module Bosh::Director::DeploymentPlan
  class IpProvider
    # @param [String] network_name
    # @param [NetAddr::CIDR] range
    # @return [IpAddress]
    def next_available(network_name, range)
      decremented_addresses = Bosh::Director::Models::IpAddress.
        where(network_name: network_name).
        select_map{ address - 1 }

      # find address that don't have following address
      address_without_following = Bosh::Director::Models::IpAddress.select(:address).
        where(network_name: network_name).
        exclude(address: decremented_addresses).order(:address).limit(1).first

      if address_without_following
        ip_address = NetAddr::CIDRv4.new(address_without_following.address + 1)
        return nil unless range.contains?(ip_address)
      else
        ip_address = range.first(Objectify: true)
      end

      IpAddress.new(ip_address, network_name)
    end
  end

  class IpAddress
    attr_reader :address, :network_name

    # @param [NetAddr::CIDR] address
    # @param [String] network_name
    def initialize(address, network_name)
      @address = address
      @network_name = network_name
    end

    def reserve
      Bosh::Director::Models::IpAddress.new(
        address: @address.to_i,
        network_name: @network_name,
      ).save
    end

    def release
      ip_address = Bosh::Director::Models::IpAddress.first(
        address: @address.to_i,
        network_name: @network_name,
      )
      raise 'Failed to release non-existing IP' unless ip_address
      ip_address.destroy
    end
  end
end
