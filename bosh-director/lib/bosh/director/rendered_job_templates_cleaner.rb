module Bosh::Director
  class RenderedJobTemplatesCleaner
    def initialize(instance_model, blobstore)
      @instance_model = instance_model
      @blobstore = blobstore
    end

    def clean
      @instance_model.stale_rendered_templates_archives.each do |archive|
        @blobstore.delete(archive.blobstore_id)
        archive.delete
      end
    end

    def clean_all
      @instance_model.rendered_templates_archives.each do |archive|
        @blobstore.delete(archive.blobstore_id)
        archive.delete
      end
    end
  end
end
