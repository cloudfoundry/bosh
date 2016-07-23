module Bosh::Director
  class BlobstoreDnsPublisher
    def initialize(blobstore, domain_name)
      @blobstore = blobstore
      @domain_name = domain_name
    end

    def broadcast
      blob = nil
      Config.db.transaction(:isolation => :committed, :retry_on => [Sequel::SerializationFailure]) do
        blob = Models::LocalDnsBlob.order(Sequel.desc(:id)).limit(1).first
      end
      AgentBroadcaster.new.sync_dns(blob.blobstore_id, blob.sha1, blob.version) unless blob.nil?
    end

    def publish(dns_records)
      json_records = dns_records.to_json
      blobstore_id = @blobstore.create(json_records)
        Models::LocalDnsBlob.create(:blobstore_id => blobstore_id,
                                    :sha1 => Digest::SHA1.hexdigest(json_records),
                                    :version => dns_records.version,
                                    :created_at => Time.new)
      blobstore_id
    end

    def export_dns_records
      hosts = []
      records = nil
      Config.db.transaction(:isolation => :committed, :retry_on => [Sequel::SerializationFailure]) do
        records = Models::LocalDnsRecord.all
      end
      version = records.max_by{|r| r.id }
      version = version.nil? ? 0 : version.id
      records.each do |dns_record|
          hosts << [dns_record.ip, dns_record.name]
      end
      DnsRecords.new(hosts, version)
    end

    def cleanup_blobs
      dns_blobs = Models::LocalDnsBlob.order(:id).all
      last_record = dns_blobs.last
      dns_blobs = dns_blobs - [ last_record ]
      return if dns_blobs.empty?

      dns_blobs.each do |blob|
        begin
          Models::EphemeralBlob.create(:blobstore_id => blob.blobstore_id, :sha1 => blob.sha1, :created_at => blob.created_at)
        rescue Sequel::ValidationFailed, Sequel::DatabaseError => e
          error_message = e.message.downcase
          raise e unless (error_message.include?('unique') || error_message.include?('duplicate'))
        end
      end
      Models::LocalDnsBlob.where('id != ?', last_record.id).delete
    end
  end
end
