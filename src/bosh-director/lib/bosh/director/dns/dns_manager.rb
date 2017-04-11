module Bosh::Director
  class DnsManagerProvider
    def self.create
      dns_config = Config.dns || {}

      logger = Config.logger
      canonized_dns_domain_name = Config.canonized_dns_domain_name

      dns_provider = PowerDns.new(canonized_dns_domain_name, logger) if !!Config.dns_db

      blobstore_provider = lambda { App.instance.blobstores.blobstore }
      agent_broadcaster = AgentBroadcaster.new
      dns_publisher = BlobstoreDnsPublisher.new(blobstore_provider, canonized_dns_domain_name, agent_broadcaster, logger)
      local_dns_repo = LocalDnsRepo.new(logger)
      DnsManager.new(canonized_dns_domain_name, dns_config, dns_provider, dns_publisher, local_dns_repo, logger)
    end
  end

  class DnsManager
    attr_reader :dns_domain_name

    def initialize(dns_domain_name, dns_config, dns_provider, dns_publisher, local_dns_repo, logger)
      @dns_domain_name = dns_domain_name
      @dns_provider = dns_provider
      @dns_publisher = dns_publisher
      @flush_command = dns_config['flush_command']
      @ip_address = dns_config['address']
      @logger = logger
      @local_dns_repo = local_dns_repo
    end

    def dns_enabled?
      !@dns_provider.nil?
    end

    def configure_nameserver
      @dns_provider.create_or_update_nameserver(@ip_address) if dns_enabled?
    end

    def find_dns_record(dns_record_name, ip_address)
      @dns_provider.find_dns_record(dns_record_name, ip_address)
    end

    def update_dns_record_for_instance(instance_model, dns_names_to_ip)
      current_dns_records = find_dns_record_names_by_instance(instance_model)
      new_dns_records = []
      dns_names_to_ip.each do |record_name, ip_address|
        new_dns_records << record_name
        if dns_enabled?
          @logger.info("Updating DNS for: #{record_name} to #{ip_address}")
          @dns_provider.create_or_update_dns_records(record_name, ip_address)
        end
      end
      dns_records = (current_dns_records + new_dns_records).uniq
      instance_model.update(dns_record_names: dns_records)
      @local_dns_repo.update_for_instance(instance_model)
    end

    def migrate_legacy_records(instance_model)
      return if find_dns_record_names_by_instance(instance_model).any?
      return unless dns_enabled?

      index_pattern_for_all_networks = DnsNameGenerator.dns_record_name(
        instance_model.index,
        instance_model.job,
        '%',
        instance_model.deployment.name
      )
      uuid_pattern_for_all_networks = DnsNameGenerator.dns_record_name(
        instance_model.uuid,
        instance_model.job,
        '%',
        instance_model.deployment.name
      )

      legacy_record_names = [index_pattern_for_all_networks, uuid_pattern_for_all_networks]
        .map { |pattern| @dns_provider.find_dns_records_by_pattern(pattern) }
        .flatten
        .map(&:name)

      instance_model.update(dns_record_names: legacy_record_names)
    end

    def delete_dns_for_instance(instance_model)
      if dns_enabled?
        current_dns_records = find_dns_record_names_by_instance(instance_model)
        if current_dns_records.empty?
          # for backwards compatibility when old instances
          # did not have records in local repo
          # we cannot migrate them because powerdns can be different database
          # those instance only had index-based dns records (before global-net)
          index_record_pattern = DnsNameGenerator.dns_record_name(instance_model.index, instance_model.job, '%', instance_model.deployment.name)
          @dns_provider.delete(index_record_pattern)
          return
        end

        current_dns_records.each do |record_name|
          @logger.info("Removing DNS for: #{record_name}")
          @dns_provider.delete(record_name)
        end
      end

      instance_model.update(dns_record_names: [])
      @local_dns_repo.delete_for_instance(instance_model)
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
      publish_dns_records
    end

    def publish_dns_records
      @dns_publisher.publish_and_broadcast
    end

    def cleanup_dns_records
      @dns_publisher.cleanup_blobs
    end

    def find_dns_record_names_by_instance(instance_model)
      instance_model.nil? ? [] : instance_model.dns_record_names.to_a.compact
    end

    def find_local_dns_record(instance_model)
      @logger.debug('Find local dns records')
      with_valid_instance_spec_in_transaction(instance_model) do |ip, network_name|
        @logger.debug("Finding local dns record with ip #{ip}")
        return Models::LocalDnsRecord.where(:ip => ip, :instance_id => instance_model.id ).all
      end
    end

    private

    def with_valid_instance_spec_in_transaction(instance_model, &block)
      spec = instance_model.spec
      unless spec.nil? || spec['networks'].nil?
        @logger.debug("Found #{spec['networks'].length} networks")
        spec['networks'].each do |network_name, network|
          unless network['ip'].nil?
            block.call(network['ip'], network_name)
          end
        end
      end
    end
  end
end
