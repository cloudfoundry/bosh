module Bosh::Director::Jobs
  module Helpers
    class TemplateDeleter
      def initialize(blobstore, logger)
        @blobstore = blobstore
        @logger = logger
      end

      def delete(template, force)
        @logger.info("Deleting job: #{template.name}/#{template.version}")

        begin
          @blobstore.delete(template.blobstore_id)
        rescue Exception => e
          raise e unless force
        end

        template.remove_all_release_versions
        template.destroy
      end
    end
  end
end
