require 'bosh/director/job_template_loader'
require 'bosh/director/job_instance_renderer'

module Bosh::Director
  class ConfigurationHasher
    # @param [DeploymentPlan::Job]
    def initialize(job)
      @job = job
    end

    def hash
      job_template_loader = JobTemplateLoader.new
      job_instance_renderer = JobInstanceRenderer.new(@job, job_template_loader)

      @job.instances.each do |instance|
        rendered_job_templates = job_instance_renderer.render(instance)
        instance_digest, template_digests = render_digest(rendered_job_templates)
        instance.configuration_hash = instance_digest.hexdigest
        instance.template_hashes = template_digests
      end
    end

    private

    def render_digest(rendered_job_templates)
      instance_digest = Digest::SHA1.new
      template_digests = {}
      rendered_job_templates.each do |rendered_job_template|
        bound_templates = ''
        bound_templates << rendered_job_template.monit

        rendered_job_template.templates.keys.sort.each do |src_name|
          bound_templates << rendered_job_template.templates[src_name]
          instance_digest << bound_templates

          template_digest = Digest::SHA1.new
          template_digest << bound_templates
          template_digests[rendered_job_template.name] = template_digest.hexdigest
        end
      end
      return instance_digest, template_digests
    end
  end
end
