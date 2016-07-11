module Bosh::Director
  class BlobstoreDnsPublisher
    def initialize(blobstore, domain_name)
      @blobstore = blobstore
      @domain_name = domain_name
    end

    def broadcast
      blob = Models::LocalDnsBlob.order(Sequel.desc(:id)).limit(1).first
      AgentBroadcaster.new.sync_dns(blob.blobstore_id, blob.sha1, blob.version) unless blob.nil?
    end

    def publish(dns_records)
      blobstore_id = nil
      json_records = dns_records.to_json
      blobstore_id = @blobstore.create(json_records)
      Models::LocalDnsBlob.create(:blobstore_id => blobstore_id,
                                  :sha1 => Digest::SHA1.hexdigest(json_records),
                                  :version => dns_records.version,
                                  :created_at => Time.new)
      blobstore_id
    end

    def export_dns_records
      hosts, version = [], nil
      version = Models::LocalDnsRecord.max(:id) || 0
      Models::LocalDnsRecord.all{|r| r.id <= version}.map do |dns_record|
          hosts << [dns_record.ip, dns_record.name]
      end
      DnsRecords.new(hosts, version)
    end

    def cleanup_blobs
      dns_blobs = Models::LocalDnsBlob.order(:id).all
      dns_blobs = dns_blobs - [ dns_blobs.last ]
      dns_blobs.each do |blob|
        Models::EphemeralBlob.create(:blobstore_id => blob.blobstore_id, :sha1 => blob.sha1, :created_at => blob.created_at)
        blob.delete
      end
    end
  end
end
