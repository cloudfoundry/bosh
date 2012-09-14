# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module DnsHelper

    # TODO serial can't be 0
    # primary_ns contact serial refresh retry expire minimum
    SOA = "localhost hostmaster@localhost 0 10800 604800 30"
    TTL_5M = 300
    TTL_4H = 3600 * 4

    # @param [String] ip IP address
    # @return [String] reverse dns domain name for an IP
    def reverse_domain(ip)
      reverse(ip, 2)
    end

    # @param [String] ip IP address
    # @return [String] reverse dns name for an IP used for a PTR record
    def reverse_host(ip)
      reverse(ip, 3)
    end

    # TODO: rename to reflect DNS-related purpose
    def canonical(string)
      # a-z, 0-9, -, case insensitive, and must start with a letter
      string = string.downcase.gsub(/_/, "-").gsub(/[^a-z0-9-]/, "")
      if string =~ /^(\d|-)/
        raise DnsInvalidCanonicalName,
              "Invalid DNS canonical name `#{string}', must begin with a letter"
      end
      if string =~ /-$/
        raise DnsInvalidCanonicalName,
              "Invalid DNS canonical name `#{string}', can't end with a hyphen"
      end
      string
    end

    def dns_servers(network, spec)
      servers = nil
      dns_property = safe_property(spec, "dns",
                                   :class => Array, :optional => true)
      if dns_property
        servers = []
        dns_property.each do |dns|
          dns = NetAddr::CIDR.create(dns)
          unless dns.size == 1
            invalid_dns(network, "must be a single IP")
          end

          servers << dns.ip
        end
      end

      servers
    end

    def delete_dns_records(record_pattern, domain_id=nil)
      records = Models::Dns::Record.filter(:name.like(record_pattern))
      if domain_id
        records = records.filter(:domain_id => domain_id)
      end

      # delete A records and collect all IPs for later
      ips = []
      records.each do |record|
        ips << record.content
        @logger.info("Deleting DNS record: #{record.name}")
        record.destroy
      end

      # delete PTR records
      ips.each do |ip|
        records = Models::Dns::Record.filter(:name.like(reverse_host(ip)))
        records.each do |record|
          @logger.info("Deleting reverse DNS record: #{record.name}")
          record.destroy
        end
      end
      # what about SOA & NS records?
      # do we mind leaving them around even if we don't have any PTR records?
    end


    # @param [String] network name
    # @param [String] reason
    # @raise NetworkInvalidDns
    def invalid_dns(network, reason)
      raise NetworkInvalidDns,
            "Invalid DNS for network `#{network}': #{reason}"
    end

    private

    def reverse(ip, n)
      octets = ip.split(/\./)
      "#{octets.reverse[0..n].join(".")}.in-addr.arpa"
    end

  end
end