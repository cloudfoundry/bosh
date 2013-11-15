require 'bosh/director/job_template_loader'
require 'bosh/director/job_instance_renderer'
require 'bosh/director/rendered_job_instance_hasher'

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
        rendered_templates = job_instance_renderer.render(instance)
        hasher = RenderedJobInstanceHasher.new(rendered_templates)
        instance.configuration_hash = hasher.configuration_hash
        instance.template_hashes = hasher.template_hashes
      end
    end
  end
end
