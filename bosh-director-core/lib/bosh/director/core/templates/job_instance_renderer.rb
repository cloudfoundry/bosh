require 'bosh/director/core/templates'
require 'bosh/director/core/templates/rendered_job_instance'

module Bosh::Director::Core::Templates
  class JobInstanceRenderer
    def initialize(templates, job_template_loader)
      @templates = templates
      @job_template_loader = job_template_loader
    end

    def render(spec)
      rendered_templates = @templates.map do |template|
        job_template_renderer = job_template_renderers[template.name]
        job_template_renderer.render(spec)
      end

      RenderedJobInstance.new(rendered_templates)
    end

    private

    def job_template_renderers
      @job_template_renderers ||= @templates.reduce({}) do |hash, template|
        hash[template.name] = @job_template_loader.process(template)
        hash
      end
    end
  end
end
