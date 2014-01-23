require 'bosh/director/core/templates/job_template_loader'
require 'bosh/director/core/templates/job_instance_renderer'

module Bosh::Director
  class JobRenderer
    # @param [DeploymentPlan::Job]
    def initialize(job)
      @job = job
      job_template_loader = Core::Templates::JobTemplateLoader.new(Config.logger)
      @instance_renderer = Core::Templates::JobInstanceRenderer.new(@job, job_template_loader)
    end

    def render_job_instances(blobstore)
      @job.instances.each do |instance|
        rendered_job_instance = @instance_renderer.render(instance)

        configuration_hash = rendered_job_instance.configuration_hash

        archive_model = instance.model.latest_rendered_templates_archive
        if archive_model && archive_model.content_sha1 == configuration_hash
          rendered_templates_archive = Core::Templates::RenderedTemplatesArchive.new(archive_model.blobstore_id, archive_model.sha1)
        else
          rendered_templates_archive = rendered_job_instance.persist(blobstore)
          instance.model.add_rendered_templates_archive(
            blobstore_id: rendered_templates_archive.blobstore_id,
            sha1: rendered_templates_archive.sha1,
            content_sha1: configuration_hash,
            created_at: Time.now,
          )
        end

        instance.configuration_hash = configuration_hash
        instance.template_hashes    = rendered_job_instance.template_hashes
        instance.rendered_templates_archive = rendered_templates_archive
      end
    end
  end
end
