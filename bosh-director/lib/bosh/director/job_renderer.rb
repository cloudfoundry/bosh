require 'bosh/director/job_template_loader'
require 'bosh/director/job_instance_renderer'
require 'bosh/director/rendered_job_instance_hasher'
require 'bosh/director/rendered_job_templates_persister'

module Bosh::Director
  class JobRenderer
    # @param [DeploymentPlan::Job]
    def initialize(job)
      @job = job
      job_template_loader = JobTemplateLoader.new
      @instance_renderer = JobInstanceRenderer.new(@job, job_template_loader)
    end

    def render_job_instances(blobstore)
      @job.instances.each do |instance|
        rendered_templates = @instance_renderer.render(instance)

        hasher = RenderedJobInstanceHasher.new(rendered_templates)
        configuration_hash = hasher.configuration_hash
        template_hashes = hasher.template_hashes

        persister = RenderedJobTemplatesPersister.new(blobstore)
        archive_model = instance.model.latest_rendered_templates_archive

        if archive_model && archive_model.content_sha1 == configuration_hash
          rendered_templates_archive = DeploymentPlan::RenderedTemplatesArchive.new(archive_model.blobstore_id, archive_model.sha1)
        else
          rendered_templates_archive = persister.persist(rendered_templates)
          instance.model.add_rendered_templates_archive(
            blobstore_id: rendered_templates_archive.blobstore_id,
            sha1: rendered_templates_archive.sha1,
            content_sha1: configuration_hash,
            created_at: Time.now,
          )
        end

        instance.configuration_hash = configuration_hash
        instance.template_hashes    = template_hashes
        instance.rendered_templates_archive = rendered_templates_archive
      end
    end
  end
end
