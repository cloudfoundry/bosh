module Bosh::Director
  class BlobstoreDnsPublisher
    def initialize(blobstore_provider, domain_name, agent_broadcaster, logger)
      @blobstore_provider = blobstore_provider
      @domain_name = domain_name
      @logger = logger
      @agent_broadcaster = agent_broadcaster
    end

    def publish_and_broadcast
      dns_blob = publish
      return if dns_blob.nil?

      @logger.debug("Broadcasting DNS blob version:#{dns_blob.version}")
      broadcast(dns_blob)
    end

    def publish_and_send_to_instance(instance_model)
      dns_blob = publish
      return if dns_blob.nil?

      send_to_instance(dns_blob, instance_model)
    end

    private

    def publish
      return unless Config.local_dns_enabled?

      dns_blob_to_broadcast
    end

    def broadcast(dns_blob)
      @agent_broadcaster.sync_dns(
        @agent_broadcaster.filter_instances(nil),
        dns_blob.blob.blobstore_id,
        dns_blob.blob.sha1,
        dns_blob.version,
      )
    end

    def send_to_instance(dns_blob, instance_model)
      @agent_broadcaster.sync_dns(
        [instance_model],
        dns_blob.blob.blobstore_id,
        dns_blob.blob.sha1,
        dns_blob.version,
      )
    end

    def records_version
      Models::LocalDnsRecord.max(:id) || 0
    end

    def aliases_version
      Models::LocalDnsAlias.max(:id) || 0
    end

    def dns_blob_to_broadcast
      latest_records_version = latest_aliases_version = current_blob = nil
      Config.db.transaction(isolation: :committed, retry_on: [Sequel::SerializationFailure]) do
        latest_records_version = records_version
        latest_aliases_version = aliases_version
        current_blob = Models::LocalDnsBlob.where(Sequel.~(version: nil)).order(:version).last
      end

      return current_blob if current_blob &&
                             current_blob.records_version >= latest_records_version &&
                             current_blob.aliases_version >= latest_aliases_version

      if current_blob&.blob
        @logger.debug("Current DNS blob version: #{current_blob.version} has shasum #{current_blob.blob.sha1}")
      else
        @logger.debug('No current DNS blob')
      end

      exported = export_dns_records

      @logger.debug("Exporting new DNS records blob with shasum: #{exported[:records].shasum}")

      create_dns_blob(**exported)
    end

    def create_dns_blob(records:, records_version:, aliases_version:)
      dns_blob = Models::LocalDnsBlob.create
      records.version = dns_blob.id

      blob = Models::Blob.create(
        blobstore_id: @blobstore_provider.call.create(records.to_json),
        sha1: records.shasum,
        created_at: Time.new,
      )
      dns_blob.update(
        blob_id: blob.id,
        version: records.version,
        created_at: blob.created_at,
        records_version: records_version,
        aliases_version: aliases_version,
      )

      dns_blob
    end

    def add_aliases(aliases, dns_records)
      aliases.each do |a|
        dns_records.add_alias(
          a.domain,
          root_domain: @domain_name,
          group_id: a.group_id,
          health_filter: a.health_filter,
          initial_health_check: a.initial_health_check,
          placeholder_type: a.placeholder_type,
        )
      end
    end

    def export_dns_records
      current_blob = Models::LocalDnsBlob.order(:version).last
      version = current_blob&.version || 0

      aliases = latest_aliases_version = local_dns_records = latest_records_version = nil
      Config.db.transaction(isolation: :committed, retry_on: [Sequel::SerializationFailure]) do
        latest_records_version = records_version
        latest_aliases_version = aliases_version

        local_dns_records = Models::LocalDnsRecord.exclude(instance_id: nil).eager(:instance).all
        aliases = Models::LocalDnsAlias.exclude(deployment_id: nil).all
      end

      dns_encoder = LocalDnsEncoderManager.create_dns_encoder
      dns_records = DnsRecords.new(version, Config.local_dns_include_index?, dns_encoder)

      add_aliases(aliases, dns_records)

      local_dns_records&.each do |dns_record|
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

      { records: dns_records, records_version: latest_records_version, aliases_version: latest_aliases_version }
    end
  end
end
