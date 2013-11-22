module Bosh::Director
  class RenderedJobTemplatesCleaner
    def initialize(instance_model, blobstore = Bosh::Blobstore::NullBlobstoreClient.new)
      @instance_model = instance_model
      @blobstore = blobstore
    end

    def clean
      instance_archives = Models::RenderedTemplatesArchive.filter(instance: instance_model)
      current_archive = instance_archives.reverse_order(:created_at).first
      return unless current_archive

      instance_archives.exclude(id: current_archive.id).each do |archive|
        blobstore.delete(archive.blob_id)
        archive.delete
      end
    end

    def clean_all
      archives = Models::RenderedTemplatesArchive.filter(instance: instance_model)
      archives.each do |archive|
        blobstore.delete(archive.blob_id)
        archive.delete
      end
    end

    private

    attr_reader :instance_model, :blobstore
  end
end
