module Bosh::Director
  class BlobstoreDnsPublisher
    def initialize(blobstore, domain_name)
      @blobstore = blobstore
      @domain_name = domain_name
    end

    def broadcast
      blob = Models::LocalDnsBlob.latest
      AgentBroadcaster.new.sync_dns(blob.blobstore_id, blob.sha1, blob.version) unless blob.nil?
    end

    def publish(dns_records)
      json_records = dns_records.to_json
      blobstore_id = @blobstore.create(json_records)
        Models::LocalDnsBlob.create(:blobstore_id => blobstore_id,
                                    :sha1 => ::Digest::SHA1.hexdigest(json_records),
                                    :version => dns_records.version,
                                    :created_at => Time.new)
      blobstore_id
    end

    def export_dns_records
      local_dns_records = nil
      version = nil
      Config.db.transaction(:isolation => :committed, :retry_on => [Sequel::SerializationFailure]) do
        version = Models::LocalDnsRecord.max(:id) || 0
        local_dns_records = Models::LocalDnsRecord.exclude(instance_id: nil).eager(:instance).all
      end

      dns_records = DnsRecords.new(version)
      local_dns_records.each do |dns_record|
        dns_records.add_record(dns_record.instance.uuid, dns_record.instance_group, dns_record.az,
          dns_record.network, dns_record.deployment, dns_record.ip, dns_record.name)
      end
      dns_records
    end

    def cleanup_blobs
      dns_blobs = Models::LocalDnsBlob.order(:id).all
      last_record = dns_blobs.last
      dns_blobs = dns_blobs - [last_record]
      return if dns_blobs.empty?

      dns_blobs.each do |blob|
        begin
          Models::EphemeralBlob.create(:blobstore_id => blob.blobstore_id, :sha1 => blob.sha1, :created_at => blob.created_at)
        rescue Sequel::ValidationFailed, Sequel::DatabaseError => e
          error_message = e.message.downcase
          raise e unless (error_message.include?('unique') || error_message.include?('duplicate'))
        end
      end
      Models::LocalDnsBlob.where('id < ?', last_record.id).delete
    end
  end
end
