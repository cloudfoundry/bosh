module Bosh::Director::Jobs
  module Helpers
    class EphemeralBlobDeleter
      def initialize(blob_deleter, logger)
        @blob_deleter = blob_deleter
        @logger = logger
      end

      def delete(ephemeral_blob, force)
        @logger.info("Deleting ephemeral blob with id '#{ephemeral_blob.blobstore_id}' created at '#{ephemeral_blob.created_at}'")
        errors = []
        if @blob_deleter.delete(ephemeral_blob.blobstore_id, errors, force)
          ephemeral_blob.destroy
        end
        errors
      end
    end
  end
end
