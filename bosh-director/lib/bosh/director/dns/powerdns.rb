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
      records = Models::Dns::Record.grep(:name, record_pattern)
      records.filter(:domain_id => find_domain_id).all
    end

    def delete(record_pattern)
      records = find_dns_records_by_pattern(record_pattern)

      # delete A records and collect all IPs for later
      ips = []
      records.each do |record|
        ips << record.content
        Models::Dns::Record.grep(:content, record.name).each do |ptr|
          @logger.info("Deleting reverse DNS record: #{ptr.name} -> #{ptr.content}")
          ptr.destroy
        end
        @logger.info("Deleting DNS record: #{record.name}")
        record.destroy
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

      rdomain = Models::Dns::Domain.safe_find_or_create(name: reverse_domain, type: 'NATIVE')

      Models::Dns::Record.find_or_create(
        domain: rdomain,
        name: reverse_domain,
        type: 'SOA', content: SOA,
        ttl: TTL_4H
      )

      Models::Dns::Record.find_or_create(
        domain: rdomain,
        name: reverse_domain,
        type: 'NS', ttl: TTL_4H,
        content: "ns.#{@domain_name}"
      )

      record = Models::Dns::Record.find_or_create(content: record_name, type: 'PTR')
      record.update(
        domain: rdomain,
        name: reverse_host,
        content: record_name,
        type: 'PTR',
        ttl: TTL_5M,
        change_date: Time.now.to_i
      )
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
  end
end
