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
        rendered_templates_archive = persister.persist(configuration_hash, instance.model, rendered_templates)

        instance.configuration_hash = configuration_hash
        instance.template_hashes    = template_hashes
        instance.rendered_templates_archive = rendered_templates_archive
      end
    end
  end
end
