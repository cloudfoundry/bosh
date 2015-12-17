module Bosh::Director
  class PowerDns
    SOA = 'localhost hostmaster@localhost 0 10800 604800 30'
    TTL_5M = 300
    TTL_4H = 3600 * 4
    TTL_5H = 3600 * 5

    def initialize(domain_name, logger)
      @domain_name = domain_name
      @logger = logger
    end

    def find_dns_record(dns_record_name, ip_address)
      Models::Dns::Record.find(name: dns_record_name, type: 'A', content: ip_address)
    end

    def find_dns_records_by_ip(ip_address)
      domain_id = find_domain_id
      return [] unless domain_id

      Models::Dns::Record.filter(domain_id: domain_id, type: 'A', content: ip_address)
    end

    def create_or_update_nameserver(ip_address)
      create_or_update_domain
      create_or_update_record(@domain_name, SOA, TTL_5M, 'SOA')
      create_or_update_record(@domain_name, "ns.#{@domain_name}", TTL_4H, 'NS')
      create_or_update_record("ns.#{@domain_name}", ip_address, TTL_5H, 'A')
    end

    def create_or_update_dns_records(dns_record_name, ip_address)
      create_or_update_record(dns_record_name, ip_address, TTL_5M, 'A')
      update_ptr_record(dns_record_name, ip_address)
    end

    def find_dns_records_by_pattern(record_pattern)
      records = Models::Dns::Record.filter(:name.like(record_pattern))
      records.filter(:domain_id => find_domain_id).all
    end

    def delete(record_pattern)
      records = find_dns_records_by_pattern(record_pattern)

      # delete A records and collect all IPs for later
      ips = []
      records.each do |record|
        ips << record.content
        Models::Dns::Record.filter(:content.like(record.name)).each do |ptr|
          @logger.info("Deleting reverse DNS record: #{ptr.name} -> #{ptr.content}")
          ptr.destroy
        end
        @logger.info("Deleting DNS record: #{record.name}")
        record.destroy
      end

      # see if any of the reverse domains are empty and should be deleted
      ips.each do |ip|
        reverse = reverse_domain(ip)
        rdomain = Models::Dns::Domain.filter(name: reverse,
          type: 'NATIVE')
        rdomain.each do |domain|
          delete_empty_domain(domain)
        end
      end
    end

    private

    def create_or_update_domain
      Models::Dns::Domain.safe_find_or_create(name: @domain_name, type: 'NATIVE')
    end

    def create_or_update_record(dns_record_name, ip_address, ttl, type)
      record = Models::Dns::Record.find(name: dns_record_name, type: type)
      if record.nil?
        domain = create_or_update_domain
        record = Models::Dns::Record.new(domain_id: domain.id,
          name: dns_record_name, type: type,
          ttl: ttl)
      end
      record.content = ip_address
      record.change_date = Time.now.to_i
      record.save
    end

    # create/update DNS PTR records (for reverse lookups)
    def update_ptr_record(record_name, ip_address)
      reverse_domain = reverse_domain(ip_address)
      reverse_host = reverse_host(ip_address)

      rdomain = Models::Dns::Domain.safe_find_or_create(name: reverse_domain,
        type: 'NATIVE')
      Models::Dns::Record.find_or_create(domain_id: rdomain.id,
        name: reverse_domain,
        type: 'SOA', content: SOA,
        ttl: TTL_4H)

      Models::Dns::Record.find_or_create(domain_id: rdomain.id,
        name: reverse_domain,
        type: 'NS', ttl: TTL_4H,
        content: "ns.#{@domain_name}")

      record = Models::Dns::Record.find(content: record_name, type: 'PTR')

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
        record = Models::Dns::Record.new(domain_id: rdomain.id,
          name: reverse_host,
          type: 'PTR', ttl: TTL_5M)
      end
      record.content = record_name
      record.change_date = Time.now.to_i
      record.save
    end

    def find_domain_id
      dns_domain = Models::Dns::Domain.find(
        :name => @domain_name,
        :type => 'NATIVE',
      )
      dns_domain.nil? ? nil : dns_domain.id
    end

    # @param [String] ip IP address
    # @return [String] reverse dns name for an IP used for a PTR record
    def reverse_host(ip)
      reverse(ip, 4)
    end

    # @param [String] ip IP address
    # @return [String] reverse dns domain name for an IP
    def reverse_domain(ip)
      reverse(ip, 3)
    end

    def reverse(ip, n)
      octets = ip.split(/\./)
      "#{octets[0..(n-1)].reverse.join(".")}.in-addr.arpa"
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
  end
end
