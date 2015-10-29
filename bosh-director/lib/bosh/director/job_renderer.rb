require 'bosh/director/core/templates/job_template_loader'
require 'bosh/director/core/templates/job_instance_renderer'

module Bosh::Director
  class JobRenderer
    def self.create
      new(App.instance.blobstores.blobstore, Config.logger)
    end

    def initialize(blobstore, logger)
      @blobstore = blobstore
      @logger = logger
    end

    def render_job_instances(job)
      job.instances.each { |instance| render_job_instance(instance) }
    end

    def render_job_instance(instance)
      @logger.debug("Rendering templates for instance #{instance}")

      job_template_loader = Core::Templates::JobTemplateLoader.new(@logger)
      instance_renderer = Core::Templates::JobInstanceRenderer.new(instance.job.templates, job_template_loader)
      rendered_job_instance = instance_renderer.render(instance.template_spec)

      configuration_hash = rendered_job_instance.configuration_hash

      archive_model = instance.model.latest_rendered_templates_archive

      if archive_model && archive_model.content_sha1 == configuration_hash
        unless @blobstore.exists?(archive_model.blobstore_id)
          # If rendered template file in blobstore crashed, we re-upload it and update database with new blobstore_id
          rendered_templates_archive = rendered_job_instance.persist(@blobstore)
          archive_model.update({:blobstore_id => rendered_templates_archive.blobstore_id, :sha1 => rendered_templates_archive.sha1})
        end
        rendered_templates_archive = Core::Templates::RenderedTemplatesArchive.new(
          archive_model.blobstore_id,
          archive_model.sha1,
        )
      else
        rendered_templates_archive = rendered_job_instance.persist(@blobstore)
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
