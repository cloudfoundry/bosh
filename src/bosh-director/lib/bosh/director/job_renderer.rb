require 'bosh/director/core/templates/job_template_loader'
require 'bosh/director/core/templates/job_instance_renderer'

module Bosh::Director
  class JobRenderer
    def self.create
      new(Config.logger)
    end

    def initialize(logger)
      @logger = logger
    end

    def render_job_instances(instance_plans)
      instance_plans.each { |instance_plan| render_job_instance(instance_plan) }
    end

    def render_job_instance(instance_plan)
      instance = instance_plan.instance

      if instance_plan.templates.empty?
        @logger.debug("Skipping rendering templates for '#{instance}', no templates")
        return
      end

      @logger.debug("Rendering templates for instance #{instance}")

      job_template_loader = Core::Templates::JobTemplateLoader.new(@logger)

      instance_renderer = Core::Templates::JobInstanceRenderer.new(instance_plan.templates, job_template_loader)
      rendered_job_instance = instance_renderer.render(instance_plan.spec.as_template_spec)

      instance_plan.rendered_templates = rendered_job_instance

      instance.configuration_hash = rendered_job_instance.configuration_hash
      instance.template_hashes    = rendered_job_instance.template_hashes
    end
  end
end
