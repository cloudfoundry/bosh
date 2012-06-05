# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  # TODO: rename to IpHelper to be consistent
  module IpUtil

    def each_ip(ranges, &block)
      if ranges.kind_of?(Array)
        ranges.each do |range|
          process_range(range, &block)
        end
      elsif ranges.kind_of?(String)
        process_range(ranges, &block)
      elsif !ranges.nil?
        raise ArgumentError,
              "Unknown range type, must be list or a string: " +
              "#{ranges.class} #{ranges}"
      end
    end

    def process_range(range)
      parts = range.split("-")
      parts.each { |part| part.strip! }
      if parts.size == 1
        range    = NetAddr::CIDR.create(parts[0])
        first_ip = range.first(:Objectify => true).to_i
        last_ip  = range.last(:Objectify => true).to_i
        (first_ip .. last_ip).each do |ip|
          yield ip
        end
      elsif parts.size == 2
        first_ip = NetAddr::CIDR.create(parts[0])
        last_ip  = NetAddr::CIDR.create(parts[1])
        raise ArgumentError unless first_ip.size == 1
        raise ArgumentError unless last_ip.size == 1
        (first_ip.to_i .. last_ip.to_i).each do |ip|
          yield ip
        end
      else
        raise ArgumentError
      end
    end

    def ip_to_i(ip)
      unless ip.kind_of?(Integer)
        unless ip.kind_of?(NetAddr::CIDR)
          ip = NetAddr::CIDR.create(ip)
        end
        ip = ip.to_i
      end
      ip
    end

    def ip_to_netaddr(ip)
      unless ip.kind_of?(NetAddr::CIDR)
        ip = NetAddr::CIDR.create(ip)
      end
      ip
    end

    # @param [Integer] ip Integer IP representation
    # @return [String] Human-readable IP representation
    def format_ip(ip)
      ip_to_netaddr(ip).ip
    end

  end
end