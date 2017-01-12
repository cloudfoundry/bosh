require 'bosh/director/core/templates'
require 'bosh/director/core/templates/rendered_job_instance'
require 'bosh/director/formatter_helper'

module Bosh::Director::Core::Templates
  class JobInstanceRenderer

    def initialize(templates, job_template_loader)
      @templates = templates
      @job_template_loader = job_template_loader
    end

    def render(spec)
      errors = []

      rendered_templates = @templates.map do |template|
        job_template_renderer = job_template_renderers[template.name]

        begin
          job_template_renderer.render(spec)
        rescue Exception => e
          errors.push e
        end
      end

      if errors.length > 0
        combined_errors = errors.map{|error| error.message.strip }.join("\n")
        header = "- Unable to render jobs for instance group '#{spec['job']['name']}'. Errors are:"
        message = Bosh::Director::FormatterHelper.new.prepend_header_and_indent_body(header, combined_errors.strip, {:indent_by => 2})
        raise message
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
