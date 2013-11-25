require 'bosh/director/rendered_templates_writer'
require 'bosh/director/compressed_rendered_job_templates'
require 'blobstore_client/null_blobstore_client'

module Bosh::Director
  class RenderedTemplatesUploader
    def initialize(blobstore = Bosh::Blobstore::NullBlobstoreClient.new)
      @blobstore = blobstore
    end

    def upload(rendered_job_templates)
      compressed_archive = CompressedRenderedJobTemplates.new(rendered_job_templates)
      @blobstore.create(compressed_archive.contents)
    end
  end
end
