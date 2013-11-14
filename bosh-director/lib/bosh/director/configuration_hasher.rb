require 'bosh/director/job_template_loader'

module Bosh::Director
  class ConfigurationHasher
    # @param [DeploymentPlan::Job]
    def initialize(job)
      @job = job
      @job_template_loader = JobTemplateLoader.new
    end

    def hash
      job_renders = @job.templates.sort { |x, y| x.name <=> y.name }.map do |job_template|
        [job_template.name, @job_template_loader.process(job_template)]
      end

      @job.instances.each do |instance|
        instance_digest, template_digests = render_digest(instance, job_renders)
        instance.configuration_hash = instance_digest.hexdigest
        instance.template_hashes = template_digests
      end
    end

    private

    def render_digest(instance, job_renderers)
      instance_digest = Digest::SHA1.new
      template_digests = {}
      job_renderers.each do |job_template_name, template_renderer|
        rendered_template = template_renderer.render(@job.name, instance)

        bound_templates = ''
        bound_templates << rendered_template.monit

        template_renderer.templates.keys.sort.each do |template_name|
          bound_templates << rendered_template.templates[template_name]
          instance_digest << bound_templates

          template_digest = Digest::SHA1.new
          template_digest << bound_templates
          template_digests[job_template_name] = template_digest.hexdigest
        end
      end
      return instance_digest, template_digests
    end
  end
end
