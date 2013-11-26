require 'bosh/director/rendered_templates_writer'
require 'bosh/director/compressed_rendered_job_templates'
require 'blobstore_client/null_blobstore_client'

module Bosh::Director
  class RenderedTemplatesUploader
    def initialize(blobstore = Bosh::Blobstore::NullBlobstoreClient.new)
      @blobstore = blobstore
    end

    def upload(rendered_job_templates)
      file = Tempfile.new('compressed-rendered-job-templates')
      compressed_archive = CompressedRenderedJobTemplates.new(file.path)
      compressed_archive.write(rendered_job_templates)
      @blobstore.create(compressed_archive.contents)
    ensure
      file.close!
    end
  end
end
