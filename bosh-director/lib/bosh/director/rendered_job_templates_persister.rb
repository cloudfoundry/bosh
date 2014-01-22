require 'tempfile'
require 'bosh/director/compressed_rendered_job_templates'
require 'bosh/director/deployment_plan/rendered_templates_archive'

module Bosh::Director
  class RenderedJobTemplatesPersister
    def initialize(blobstore)
      @blobstore = blobstore
    end

    def persist(configuration_hash, instance_model, rendered_job_templates)
      archive_model = instance_model.latest_rendered_templates_archive

      if !archive_model || archive_model.content_sha1 != configuration_hash
        archive_model = persist_without_checking(configuration_hash, instance_model, rendered_job_templates)
      end

      DeploymentPlan::RenderedTemplatesArchive.new(archive_model.blobstore_id, archive_model.sha1)
    end

    def persist_without_checking(configuration_hash, instance_model, rendered_job_templates)
      file = Tempfile.new('compressed-rendered-job-templates')

      compressed_archive = CompressedRenderedJobTemplates.new(file.path)
      compressed_archive.write(rendered_job_templates)

      blobstore_id = @blobstore.create(compressed_archive.contents)

      instance_model.add_rendered_templates_archive(
        blobstore_id: blobstore_id,
        sha1: compressed_archive.sha1,
        content_sha1: configuration_hash,
        created_at: Time.now,
      )
    ensure
      file.close!
    end
  end
end
