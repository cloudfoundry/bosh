module Bosh::Director
  class BlobstoreDnsPublisher
    def initialize(blobstore)
      @blobstore = blobstore
    end

    def publish(dns_records)
      json_records = {:records => dns_records}.to_json
      blobstore_id = @blobstore.create(json_records)
      Models::LocalDnsBlob.create(:blobstore_id => blobstore_id, :sha1 => Digest::SHA1.hexdigest(json_records), :created_at => Time.new)
      blobstore_id
    end

    def export_dns_records
      Models::LocalDnsRecord.all.map do |record|
        [record.ip, record.name]
      end
    end

    def persist_dns_record(ip, name)
      existing = Models::LocalDnsRecord.find(:name => name)

      if existing.nil?
        Models::LocalDnsRecord.create(:ip => ip, :name => name, :timestamp => Time.new)
      else
        existing.update(:ip => ip, :timestamp => Time.new)
      end
    end

    def delete_dns_record(name)
      Models::LocalDnsRecord.grep(:name, name).delete
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
