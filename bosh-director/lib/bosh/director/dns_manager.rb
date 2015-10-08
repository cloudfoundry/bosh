module Bosh::Director
  class DnsManager
    attr_reader :dns_domain_name

    def self.create
      dns_config = Config.dns || {}
      dns_enabled = !!Config.dns_db # to be consistent with current behavior
      logger = Config.logger
      new(dns_config, dns_enabled, logger)
    end

    def self.canonical(string)
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

    def initialize(dns_config, dns_enabled, logger)
      @dns_domain_name = DnsManager.canonical(dns_config.fetch('domain_name', 'bosh'))
      @dns_provider = PowerDns.new(@dns_domain_name, logger)
      @dns_enabled = dns_enabled
      @default_server = dns_config['server']
      @flush_command = dns_config['flush_command']
      @ip_address = dns_config['address']
      @logger = logger
    end

    def dns_enabled?
      @dns_enabled
    end

    def configure_nameserver
      return unless dns_enabled?

      @dns_provider.create_or_update_nameserver(@ip_address)
    end

    def find_dns_record(dns_record_name, ip_address)
      @dns_provider.find_dns_record(dns_record_name, ip_address)
    end

    def find_dns_records_by_ip(ip_address)
      @dns_provider.find_dns_records_by_ip(ip_address)
    end

    def update_dns_record_for_instance(record_name, ip_address)
      @dns_provider.create_or_update_dns_records(record_name, ip_address)
    end

    def delete_dns_for_deployment(name)
      return unless dns_enabled?

      record_pattern = ['%', canonical(name), @dns_domain_name].join('.')
      @dns_provider.delete(record_pattern)
    end

    def delete_dns_for_instance(instance_model)
      return unless dns_enabled?

      index_record_pattern = dns_record_name(instance_model.index, instance_model.job, '%', instance_model.deployment.name)
      @dns_provider.delete(index_record_pattern)

      uuid_record_pattern = dns_record_name(instance_model.uuid, instance_model.job, '%', instance_model.deployment.name)
      @dns_provider.delete(uuid_record_pattern)
    end

    # build a list of dns servers to use
    def dns_servers(network, dns_spec, add_default_dns = true)
      servers = nil

      if dns_spec
        servers = []
        dns_spec.each do |dns|
          dns = NetAddr::CIDR.create(dns)
          unless dns.size == 1
            raise NetworkInvalidDns,
              "Invalid DNS for network `#{network}': must be a single IP"
          end

          servers << dns.ip
        end
      end

      return servers unless add_default_dns
      add_default_dns_server(servers)
    end

    # Purge cached DNS records
    def flush_dns_cache
      if @flush_command && !@flush_command.empty?
        stdout, stderr, status = Open3.capture3(@flush_command)
        if status == 0
          @logger.debug("Flushed #{stdout.chomp} records from DNS cache")
        else
          @logger.warn("Failed to flush DNS cache: #{stderr.chomp}")
        end
      end
    end

    def dns_record_name(hostname, job_name, network_name, deployment_name)
      network_name = DnsManager.canonical(network_name) unless network_name == '%'

      [ hostname,
        DnsManager.canonical(job_name),
        network_name,
        DnsManager.canonical(deployment_name),
        @dns_domain_name
      ].join('.')
    end

    private

    # add default dns server to an array of dns servers
    def add_default_dns_server(servers)
      return servers unless dns_enabled?

      unless @default_server.to_s.empty? || @default_server == '127.0.0.1'
        (servers ||= []) << @default_server
        servers.uniq!
      end

      servers
    end
  end
end
