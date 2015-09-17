module Bosh::Director
  class RenderedJobTemplatesCleaner
    def initialize(instance_model, blobstore, logger)
      @instance_model = instance_model
      @blobstore = blobstore
      @logger = logger
    end

    def clean
      @instance_model.stale_rendered_templates_archives.each do |archive|
        begin
          @blobstore.delete(archive.blobstore_id)
        rescue Bosh::Blobstore::NotFound => e
          @logger.debug("Blobstore#delete error: #{e.message}, will ignore this error and delete the db record")
        end

        archive.delete
      end
    end

    def clean_all
      @instance_model.rendered_templates_archives.each do |archive|
        begin
          @blobstore.delete(archive.blobstore_id)
        rescue Bosh::Blobstore::NotFound => e
          @logger.debug("Blobstore#delete error: #{e.message}, will ignore this error and delete the db record")
        end

        archive.delete
      end
    end
  end
end
