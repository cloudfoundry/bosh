require 'bosh/director/deployment_plan/job_spec_parser'
require 'bosh/template/property_helper'

module Bosh::Director::DeploymentPlan
  class DatabaseIpProvider
    include Bosh::Director::IpUtil

    # @param [NetAddr::CIDR] range
    # @param [String] network_name
    def initialize(range, network_name, restricted_ips, static_ips)
      @range = range
      @network_name = network_name
      @restricted_ips = restricted_ips
      @static_ips = static_ips
    end

    # @return [Integer] ip
    def allocate_dynamic_ip
      # find address that doesn't have subsequent address
      if @restricted_ips.empty? && @static_ips.empty?
        addr = address_before_candidate
      else
        addr = address_before_candidate_excluding(
          (@restricted_ips + @static_ips).to_a
        )
      end

      if addr
        ip_address = NetAddr::CIDRv4.new(addr.address.to_i + 1)
        return nil unless @range.contains?(ip_address)
      else
        ip_address = @range.first(Objectify: true)
      end

      return nil unless reserve(ip_address)

      ip_address.to_i
    end

    # @param [NetAddr::CIDR] ip
    def reserve_ip(ip)
      return nil if @restricted_ips.include?(ip.to_i)

      return nil unless reserve(ip)

      @static_ips.include?(ip.to_i) ? :static : :dynamic
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
            "it's neither in dynamic nor in static pool"
      end

      ip_address.destroy
    end

    private

    # @param [NetAddr::CIDR] ip
    def reserve(ip)
      Bosh::Director::Models::IpAddress.new(
        address: ip.to_i,
        network_name: @network_name,
      ).save
    rescue Sequel::DatabaseError
      nil
    end

    def address_before_candidate
      Bosh::Director::Models::IpAddress.select(:address)
        .where(network_name: @network_name)
        .exclude(address:
            Bosh::Director::Models::IpAddress.select(:address - 1)
        ).order(:address).limit(1).first
    end

    def address_before_candidate_excluding(restricted_ips)
      decremented_reserved_ips = restricted_ips.map { |i| i.to_i - 1}

      Bosh::Director::Models::IpAddress.select(:address).where(
          network_name: @network_name
        ).union(
          dataset_from(restricted_ips)
        ).exclude(address:
            Bosh::Director::Models::IpAddress.select(
              :address - 1
            ).union(
              dataset_from(decremented_reserved_ips)
            )
        ).order(:address).limit(1).first
    end

    def dataset_from(values)
      return nil if values.empty?
      # unfortunately there is no sequel method to use values clause inline
      db = Bosh::Director::Config.db
      list = values.map{ |v| db.literal(v.to_i) }.join('), (')
      db.fetch("select * from (values (#{list}))")
    end
  end
end
