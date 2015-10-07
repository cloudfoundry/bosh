module Bosh::Director
  class DnsManager
    def initialize(logger)
      @logger = logger
    end

    # returns the DNS domain name
    def dns_domain_name
      Config.dns_domain_name
    end

    # returns the DNS name server record
    def dns_ns_record
      "ns.#{dns_domain_name}"
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

    def update_dns_record(domain_name, record_name, ip_address)
      dns_provider = PowerDns.new(domain_name, @logger)
      dns_provider.create_or_update(record_name, ip_address)
    end

    def delete_dns_for_deployment(name)
      record_pattern = ['%', canonical(name), dns_domain_name].join('.')
      delete_dns_records(record_pattern)
    end

    def delete_dns_for_instance(instance_model)
      return unless Config.dns_enabled?

      dns_provider = PowerDns.new(dns_domain_name, @logger)
      index_record_pattern = record_pattern(instance_model.index, instance_model.job, instance_model.deployment.name)
      dns_provider.delete(index_record_pattern)

      uuid_record_pattern = record_pattern(instance_model.uuid, instance_model.job, instance_model.deployment.name)
      dns_provider.delete(uuid_record_pattern)
    end

    # build a list of dns servers to use
    def dns_servers(network, dns_spec, add_default_dns = true)
      servers = nil

      if dns_spec
        servers = []
        dns_spec.each do |dns|
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

    # Purge cached DNS records
    def flush_dns_cache
      flush_command = Config.dns['flush_command']
      if flush_command && !flush_command.empty?
        stdout, stderr, status = Open3.capture3(flush_command)
        if status == 0
          @logger.debug("Flushed #{stdout.chomp} records from DNS cache")
        else
          @logger.warn("Failed to flush DNS cache: #{stderr.chomp}")
        end
      end
    end

    private

    def record_pattern(hostname, job_name, deployment_name)
      [ hostname,
        canonical(job_name),
        "%",
        canonical(deployment_name),
        dns_domain_name
      ].join(".")
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

    # @param [String] network name
    # @param [String] reason
    # @raise NetworkInvalidDns
    def invalid_dns(network, reason)
      raise NetworkInvalidDns,
        "Invalid DNS for network `#{network}': #{reason}"
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
  end
end
