module Bosh::Director::Jobs
  module Helpers
    class BlobDeleter

      def initialize(blobstore, logger)
        @blobstore = blobstore
        @logger = logger
      end

      def delete(blobstore_id, errors, force)
        begin
          @blobstore.delete(blobstore_id)
          return true
        rescue Exception => e
          @logger.warn("Could not delete blob with id '#{blobstore_id}' from blobstore: #{e}\n " + e.backtrace.join("\n"))
          errors << e
        end

        force
      end
    end
  end
end

