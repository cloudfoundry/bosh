module Bosh::Director::Jobs
  module Helpers
    class TemplateDeleter
      def initialize(blob_deleter, logger)
        @blob_deleter = blob_deleter
        @logger = logger
      end

      def delete(template, force)
        @logger.info("Deleting job: #{template.name}/#{template.version}")
        errors = []
        if @blob_deleter.delete(template.blobstore_id, errors, force)
          template.remove_all_release_versions
          template.destroy
        end
        errors
      end
    end
  end
end
