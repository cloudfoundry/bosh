module Bosh::Director
  class BlobstoreDnsPublisher
    def initialize(blobstore_provider, domain_name, agent_broadcaster, dns_query_encoder, logger)
      @blobstore_provider = blobstore_provider
      @domain_name = domain_name
      @logger = logger
      @agent_broadcaster = agent_broadcaster
      @dns_query_encoder = dns_query_encoder
    end

    def publish_and_broadcast
      if Config.local_dns_enabled?

        local_dns_blob = nil
        max_dns_record_version = nil

        Config.db.transaction(:isolation => :committed, :retry_on => [Sequel::SerializationFailure]) do
          local_dns_blob = Models::LocalDnsBlob.order(:id).last
          max_dns_record_version = Models::LocalDnsRecord.max(:id)
        end

        if local_dns_blob.nil? && max_dns_record_version.nil?
          return
        end

        if local_dns_blob.nil? || local_dns_blob.version < max_dns_record_version
          @logger.debug("Exporting local dns records max_dns_record_version:#{max_dns_record_version} local_dns_blob.version:#{local_dns_blob.nil? ? nil : local_dns_blob.version}")
          records = export_dns_records
          local_dns_blob = create_dns_blob(records)
        end

        @logger.debug("Broadcasting local_dns_blob.version:#{local_dns_blob.version}")
        broadcast(local_dns_blob)
      end
    end

    private

    def broadcast(dns_blob)
      @agent_broadcaster.sync_dns(@agent_broadcaster.filter_instances(nil), dns_blob.blob.blobstore_id, dns_blob.blob.sha1, dns_blob.version) unless dns_blob.nil?
    end

    def create_dns_blob(dns_records)
      blob = Models::Blob.create(
          blobstore_id: @blobstore_provider.call.create(dns_records.to_json),
          sha1: dns_records.shasum,
          created_at: Time.new
      )
      dns_blob = Models::LocalDnsBlob.create(
          blob_id: blob.id,
          version: dns_records.version,
          created_at: blob.created_at
      )

      dns_blob
    end

    def export_dns_records
      local_dns_records = []
      version = nil
      Config.db.transaction(:isolation => :committed, :retry_on => [Sequel::SerializationFailure]) do
        version = Models::LocalDnsRecord.max(:id) || 0
        local_dns_records = Models::LocalDnsRecord.exclude(instance_id: nil).eager(:instance).all
      end

      dns_records = DnsRecords.new(version, Config.local_dns_include_index?, @dns_query_encoder)
      local_dns_records.each do |dns_record|
        dns_records.add_record(
          dns_record.instance.uuid,
          dns_record.instance.index,
          dns_record.instance_group,
          dns_record.az,
          dns_record.network,
          dns_record.deployment,
          dns_record.ip,
          dns_record.domain.nil? ? @domain_name : dns_record.domain,
          dns_record.agent_id
        )
      end
      dns_records
    end
  end
end
