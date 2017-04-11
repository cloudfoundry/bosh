module Bosh::Director
  class BlobstoreDnsPublisher
    def initialize(blobstore_provider, domain_name, agent_broadcaster, logger)
      @blobstore_provider = blobstore_provider
      @domain_name = domain_name
      @logger = logger
      @agent_broadcaster = agent_broadcaster
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
          local_dns_blob = publish(records)
        end

        @logger.debug("Broadcasting local_dns_blob.version:#{local_dns_blob.version}")
        broadcast(local_dns_blob)
      end
    end

    def cleanup_blobs
      dns_blobs = Models::LocalDnsBlob.order(:id).all
      last_record = dns_blobs.last
      dns_blobs = dns_blobs - [last_record]
      return if dns_blobs.empty?

      dns_blobs.each do |blob|
        begin
          Models::EphemeralBlob.create(blobstore_id: blob.blobstore_id, sha1: blob.sha1, created_at: blob.created_at)
        rescue Sequel::ValidationFailed, Sequel::DatabaseError => e
          error_message = e.message.downcase
          raise e unless (error_message.include?('unique') || error_message.include?('duplicate'))
        end
      end
      Models::LocalDnsBlob.where('id < ?', last_record.id).delete
    end

    private

    def broadcast(blob)
      @agent_broadcaster.sync_dns(blob.blobstore_id, blob.sha1, blob.version) unless blob.nil?
    end

    def publish(dns_records)
      Models::LocalDnsBlob.create(
          blobstore_id: @blobstore_provider.call.create(dns_records.to_json),
          sha1: dns_records.shasum,
          version: dns_records.version,
          created_at: Time.new
      )
    end

    def export_dns_records
      local_dns_records = []
      version = nil
      Config.db.transaction(:isolation => :committed, :retry_on => [Sequel::SerializationFailure]) do
        version = Models::LocalDnsRecord.max(:id) || 0
        local_dns_records = Models::LocalDnsRecord.exclude(instance_id: nil).eager(:instance).all
      end

      dns_records = DnsRecords.new(version, Config.local_dns_include_index?)
      local_dns_records.each do |dns_record|
        dns_records.add_record(dns_record.instance.uuid, dns_record.instance.index, dns_record.instance_group,
                               dns_record.az, dns_record.network, dns_record.deployment, dns_record.ip)
      end
      dns_records
    end
  end
end
