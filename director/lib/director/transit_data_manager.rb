module Bosh::Director
  class TransitDataManager
    class << self
      def add(tag, blobstore_id)
        Models::TransitDatum.create(:tag => tag, :blobstore_id => blobstore_id, :timestamp => Time.now)
      end

      def cleanup(tag, interval)
        @logger ||= Config.logger
        @blobstore ||= Config.blobstore
        old_data = Models::TransitDatum.filter({:tag => tag}).and("timestamp <= ?",  Time.now - interval)
        count = old_data.count

        if count == 0
          @logger.info("Transit #{tag}: No old data to delete")
          return
        end

        @logger.info("Transit #{tag}: Deleting #{count} old records #{count > 1 ? "s" : ""}")

        old_data.each do |datum|
          begin
            @logger.info("Transit #{tag}: Deleting #{datum.id}: #{datum.blobstore_id}")
            @blobstore.delete(datum.blobstore_id)
            datum.delete
          rescue Bosh::Blobstore::BlobstoreError => e
            @logger.warn("Transit #{tag}: Could not delete #{datum.blobstore_id}: #{e}")
            # Assuming object has been deleted from blobstore by someone else,
            # cleaning up DB record accordingly
            if e.kind_of?(Bosh::Blobstore::NotFound)
              datum.delete
            end
          end
        end
      end
    end
  end
end
