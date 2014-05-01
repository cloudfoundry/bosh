module Bosh::Director
  class LogBundlesCleaner
    def initialize(blobstore, log_bundle_ttl, logger)
      @blobstore = blobstore
      @bundle_lifetime = log_bundle_ttl
      @logger = logger
    end

    def register_blobstore_id(blobstore_id)
      @logger.info("Registering log bundle with blobstore id #{blobstore_id}")
      Models::LogBundle.create(blobstore_id: blobstore_id, timestamp: Time.now)
    end

    def clean
      cut_off_time = Time.now - @bundle_lifetime
      old_bundles = Models::LogBundle.filter("timestamp <= ?", cut_off_time)
      @logger.info("Deleting #{old_bundles.count} old log bundle(s) before #{cut_off_time}")

      old_bundles.each do |bundle|
        begin
          @logger.info("Deleting log bundle #{bundle.id} with blobstore id #{bundle.blobstore_id}")
          @blobstore.delete(bundle.blobstore_id)
          bundle.delete
        rescue Bosh::Blobstore::BlobstoreError => e
          @logger.warn("Could not delete #{bundle.blobstore_id}: #{e.inspect}")

          # Assuming object has been deleted from blobstore by someone else,
          # cleaning up DB record accordingly
          bundle.delete if e.kind_of?(Bosh::Blobstore::NotFound)
        end
      end
    end
  end
end
