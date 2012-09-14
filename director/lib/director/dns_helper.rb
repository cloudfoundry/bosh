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

    # build a list of dns servers to use
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

    # creates or updates the bosh DNS domain
    # @return [Bosh::Director::Models::Dns::Domain] domain model
    def update_dns_domain
      domain = Models::Dns::Domain.find_or_create(:name => "bosh",
                                                  :type => "NATIVE")

      soa_record = Models::Dns::Record.find_or_create(:domain_id => domain.id,
                                                      :name => "bosh",
                                                      :type => "SOA")
      # TODO increment SOA serial
      # TODO: make configurable?
      soa_record.content = SOA
      soa_record.ttl = 300
      soa_record.save

      # add NS record
      Models::Dns::Record.find_or_create(:domain_id => domain.id,
                                         :name => "bosh",
                                         :type =>'NS', :ttl => TTL_4H,
                                         :content => "ns.bosh")
      # add A record for name server
      Models::Dns::Record.find_or_create(:domain_id => domain.id,
                                         :name => "ns.bosh",
                                         :type =>'A', :ttl => TTL_4H,
                                         :content => Config.dns["address"])

      domain
    end


    # @param [Hash[String, String]] dns_info
    def update_dns_records(dns_info, domain)
      dns_info.each do |record_name, ip_address|
        @logger.info("Updating DNS for: #{record_name} to #{ip_address}")
        record = Models::Dns::Record.find(:domain_id => domain.id,
                                          :name => record_name)
        if record.nil?
          record = Models::Dns::Record.new(:domain_id => domain.id,
                                           :name => record_name, :type => "A")
        end
        record.content = ip_address
        record.change_date = Time.now.to_i
        record.save

        # create/update records needed for reverse lookups
        reverse = reverse_domain(ip_address)
        rdomain = Models::Dns::Domain.find_or_create(:name => reverse,
                                                     :type => "NATIVE")
        Models::Dns::Record.find_or_create(:domain_id => rdomain.id,
                                           :name => reverse,
                                           :type =>'SOA', :content => SOA,
                                           :ttl => TTL_4H)

        Models::Dns::Record.find_or_create(:domain_id => rdomain.id,
                                           :name => reverse,
                                           :type =>'NS', :ttl => TTL_4H,
                                           :content => "ns.bosh")

        record = Models::Dns::Record.find(:domain_id => rdomain.id,
                                          :name => reverse,
                                          :type =>'PTR', :ttl => TTL_5M)
        unless record
          record = Models::Dns::Record.new(:domain_id => rdomain.id,
                                           :name => reverse,
                                           :type =>'PTR')
        end
        record.content = record_name
        record.change_date = Time.now.to_i
        record.save
      end
    end

    # deletes all DNS records matching the pattern
    # @param [String] record_pattern SQL pattern
    # @param [Integer] domain_id domain record id
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

      # delete PTR records from IP list
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