require 'tempfile'
require 'bosh/director/compressed_rendered_job_templates'
require 'bosh/director/deployment_plan/rendered_templates_archive'

module Bosh::Director
  class RenderedJobTemplatesPersister
    def initialize(blobstore)
      @blobstore = blobstore
    end

    def persist(rendered_job_templates)
      file = Tempfile.new('compressed-rendered-job-templates')

      compressed_archive = CompressedRenderedJobTemplates.new(file.path)
      compressed_archive.write(rendered_job_templates)

      blobstore_id = @blobstore.create(compressed_archive.contents)
      blobstore_sha1 = compressed_archive.sha1

      DeploymentPlan::RenderedTemplatesArchive.new(blobstore_id, blobstore_sha1)
    ensure
      file.close!
    end
  end
end
