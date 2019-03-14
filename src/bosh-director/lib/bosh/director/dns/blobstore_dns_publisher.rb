module Bosh::Director
  class BlobstoreDnsPublisher
    def initialize(blobstore_provider, domain_name, agent_broadcaster, logger)
      @blobstore_provider = blobstore_provider
      @domain_name = domain_name
      @logger = logger
      @agent_broadcaster = agent_broadcaster
    end

    def publish_and_broadcast
      return unless Config.local_dns_enabled?

      records = export_dns_records
      new_dns_blob = create_dns_blob(records)
      return if new_dns_blob.nil?

      @logger.debug("Broadcasting DNS blob version:#{new_dns_blob.version}")
      broadcast(new_dns_blob)
    end

    private

    def broadcast(dns_blob)
      @agent_broadcaster.sync_dns(
        @agent_broadcaster.filter_instances(nil),
        dns_blob.blob.blobstore_id,
        dns_blob.blob.sha1,
        dns_blob.version,
      )
    end

    def create_dns_blob(dns_records)
      current_blob = Models::LocalDnsBlob.order(:version).last
      return current_blob if current_blob.nil? || current_blob.blob.sha1 == dns_records.shasum

      @logger.debug("Exporting new DNS records blob with shasum: #{dns_records.shasum}")

      if current_blob
        @logger.debug("Current DNS blob version: #{current_blob.version} has shasum #{current_blob.blob.sha1}")
      else
        @logger.debug('No current DNS blob')
      end

      dns_blob = Models::LocalDnsBlob.create
      dns_records.version = dns_blob.id

      blob = Models::Blob.create(
        blobstore_id: @blobstore_provider.call.create(dns_records.to_json),
        sha1: dns_records.shasum,
        created_at: Time.new,
      )
      dns_blob.update(
        blob_id: blob.id,
        version: dns_records.version,
        created_at: blob.created_at,
      )

      dns_blob
    end

    def add_aliases(dns_records, dns_encoder)
      provider_intents = Models::Links::LinkProviderIntent.all
      provider_intents.each do |provider_intent|
        next unless provider_intent.metadata

        aliases = JSON.parse(provider_intent.metadata)['dns_aliases']
        aliases&.each do |dns_alias|
          target = dns_encoder.encode_query({
            deployment_name: provider_intent.link_provider.deployment.name,
            group_type: Models::LocalDnsEncodedGroup::Types::LINK,
            group_name: provider_intent.group_name,
            root_domain: @domain_name,
            status: dns_alias['health_filter'],
            initial_health_check: dns_alias['initial_health_check'],
          }, true)
          dns_records.add_alias(dns_alias['domain'], target)
        end
      end
    end

    def export_dns_records
      current_blob = Models::LocalDnsBlob.order(:version).last
      version = current_blob&.version || 0
      local_dns_records = Models::LocalDnsRecord.exclude(instance_id: nil).eager(:instance).all

      dns_encoder = LocalDnsEncoderManager.create_dns_encoder
      dns_records = DnsRecords.new(version, Config.local_dns_include_index?, dns_encoder)

      add_aliases(dns_records, dns_encoder)

      local_dns_records.each do |dns_record|
        dns_records.add_record(
          instance_id: dns_record.instance.uuid,
          num_id: dns_record.instance.id,
          index: dns_record.instance.index,
          instance_group_name: dns_record.instance_group,
          az_name: dns_record.az,
          network_name: dns_record.network,
          deployment_name: dns_record.deployment,
          ip: dns_record.ip,
          domain: dns_record.domain || @domain_name,
          agent_id: dns_record.agent_id,
          links: dns_record.links,
        )
      end
      dns_records
    end
  end
end
