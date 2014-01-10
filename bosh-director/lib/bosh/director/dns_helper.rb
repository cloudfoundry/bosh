module Bosh::Director
  module DnsHelper

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
    def dns_servers(network, spec, add_default_dns = true)
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

      return servers unless add_default_dns

      add_default_dns_server(servers)
    end

    # returns the default DNS server
    def default_dns_server
      Config.dns["server"] if Config.dns
    end

    # add default dns server to an array of dns servers
    def add_default_dns_server(servers)
      return servers unless Config.dns_enabled?

      default_server = default_dns_server
      if default_server && default_server != "127.0.0.1"
        (servers ||= []) << default_server
        servers.uniq!
      end

      servers
    end

    # returns the DNS domain name
    def dns_domain_name
      Config.dns_domain_name
    end

    # returns the DNS name server record
    def dns_ns_record
      "ns.#{dns_domain_name}"
    end

    # create/update DNS A record
    def update_dns_a_record(domain, name, ip_address)
      record = Models::Dns::Record.find(:domain_id => domain.id,
                                        :name => name)
      if record.nil?
        record = Models::Dns::Record.new(:domain_id => domain.id,
                                         :name => name, :type => "A",
                                         :ttl => TTL_5M)
      end
      record.content = ip_address
      record.change_date = Time.now.to_i
      record.save
    end

    # create/update DNS PTR records (for reverse lookups)
    def update_dns_ptr_record(name, ip_address)
      reverse_domain = reverse_domain(ip_address)
      reverse_host = reverse_host(ip_address)

      rdomain = Models::Dns::Domain.safe_find_or_create(:name => reverse_domain,
                                                        :type => "NATIVE")
      Models::Dns::Record.find_or_create(:domain_id => rdomain.id,
                                         :name => reverse_domain,
                                         :type =>'SOA', :content => SOA,
                                         :ttl => TTL_4H)

      Models::Dns::Record.find_or_create(:domain_id => rdomain.id,
                                         :name => reverse_domain,
                                         :type =>'NS', :ttl => TTL_4H,
                                         :content => dns_ns_record)

      record = Models::Dns::Record.find(:content => name, :type =>'PTR')

      # delete the record if the IP address changed
      if record && record.name != reverse_host
        id = record.domain_id
        record.destroy
        record = nil

        # delete the domain if the domain id changed and it's empty
        if id != rdomain.id
          delete_empty_domain(Models::Dns::Domain[id])
        end
      end

      unless record
        record = Models::Dns::Record.new(:domain_id => rdomain.id,
                                         :name => reverse_host,
                                         :type =>'PTR', :ttl => TTL_5M)
      end
      record.content = name
      record.change_date = Time.now.to_i
      record.save
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

      # see if any of the reverse domains are empty and should be deleted
      ips.each do |ip|
        reverse = reverse_domain(ip)
        rdomain = Models::Dns::Domain.filter(:name => reverse,
                                             :type => "NATIVE")
        rdomain.each do |domain|
          delete_empty_domain(domain)
        end
      end
    end

    def delete_empty_domain(domain)
      # If the count is 2, it means we only have the NS & SOA record
      # and the domain is "empty" and can be deleted
      if domain.records.size == 2
        @logger.info("Deleting empty reverse domain #{domain.name}")

        # Since DNS domain can be deleted by multiple threads
        # it's possible for database to return 0 rows modified result.
        # In this specific case that's a valid return value
        # but Sequel usually considers that an error.
        # ('Attempt to delete object did not result in a single row modification')
        domain.require_modification = false

        # Cascaded - all records are removed
        domain.destroy
      end
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
      "#{octets[0..n].reverse.join(".")}.in-addr.arpa"
    end
  end
end
