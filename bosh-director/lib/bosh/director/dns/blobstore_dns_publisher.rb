module Bosh::Director
  class BlobstoreDnsPublisher
    def initialize(blobstore, domain_name)
      @blobstore = blobstore
      @domain_name = domain_name
    end

    def publish(dns_records)
      json_records = {:records => dns_records}.to_json
      blobstore_id = @blobstore.create(json_records)
      Models::LocalDnsBlob.create(:blobstore_id => blobstore_id, :sha1 => Digest::SHA1.hexdigest(json_records), :created_at => Time.new)
      blobstore_id
    end

    def export_dns_records
      hosts = []
      Models::Instance.all.map do |instance|
        spec = instance.spec
        spec['networks'].each do |network_name, network|
          hosts << [ network['ip'], spec['id'] + '.' + spec['name'] + '.' + network_name + '.' + spec['deployment'] + '.' + @domain_name ]
        end
      end
      hosts
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
