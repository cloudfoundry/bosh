module Bosh::Director
  class RenderedJobTemplatesCleaner
    def initialize(instance, blobstore = Bosh::Blobstore::NullBlobstoreClient.new)
      @instance = instance
      @blobstore = blobstore
    end

    def clean
      instance_archives = Models::RenderedTemplatesArchive.filter(instance: instance.model)
      current_archive = instance_archives.reverse_order(:created_at).first
      instance_archives.exclude(id: current_archive.id).each do |archive|
        blobstore.delete(archive.blob_id)
        archive.delete
      end
    end

    private

    attr_reader :instance, :blobstore
  end
end
