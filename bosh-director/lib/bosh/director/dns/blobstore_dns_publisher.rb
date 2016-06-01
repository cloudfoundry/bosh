module Bosh::Director
  class BlobstoreDnsPublisher
    def initialize(blobstore)
      @blobstore = blobstore
    end

    def publish(dns_records)
      json_records = {:records => dns_records}.to_json
      @blobstore.create(json_records)
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
      # finds record and deletes entry
    end
  end
end
