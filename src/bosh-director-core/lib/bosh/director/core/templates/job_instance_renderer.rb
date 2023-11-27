require 'bosh/director/core/templates'
require 'bosh/director/core/templates/rendered_job_instance'
require 'bosh/director/formatter_helper'

module Bosh::Director::Core::Templates

  # @param [Array<DeploymentPlan::Job>] instance_jobs
  # @param [JobTemplateLoader] job_template_loader
  class JobInstanceRenderer
    def initialize(templates, job_template_loader)
      @templates = templates
      @job_template_loader = job_template_loader
    end

    # Render all templates for a Bosh instance.
    #
    # From a list of instance jobs (typically comming from a single instance
    # plan, so they cover all templates of some instance) this method is
    # responsible for orchestrating several tasks.
    #
    # Lazily-delegated work to a 'JobTemplateLoader' object:
    #   - Load all templates of the release job that the instance job is
    #     referring to
    #   - Convert each of these to a 'JobTemplateRenderer' object
    #
    # Work done here on top of this:
    #   - Render each template with the necessary bindings (comming from
    #     deployment manifest properties) for building the special 'spec'
    #     object that the ERB rendring code can use.
    #
    # The actual rendering of each template is delegated to its related
    # 'JobTemplateRenderer' object, as created in the first place by the
    # 'JobTemplateLoader' object.
    #
    # @param [Hash] spec_object A hash of properties that will finally result
    #                           in the `spec` object exposed to ERB templates
    # @return [RenderedJobInstance] An object containing the rendering results
    #                               (when successful)
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
