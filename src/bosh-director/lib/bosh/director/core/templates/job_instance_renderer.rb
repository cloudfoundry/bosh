require 'bosh/director/core/templates'
require 'bosh/director/core/templates/rendered_job_instance'
require 'bosh/director/formatter_helper'

module Bosh::Director::Core::Templates

  # @param [Array<DeploymentPlan::Job>] instance_jobs
  # @param [JobTemplateLoader] job_template_loader
  class JobInstanceRenderer
    def initialize(instance_jobs, job_template_loader)
      @instance_jobs = instance_jobs
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
    def render(spec_object)
      errors = []

      rendered_templates = @instance_jobs.map do |instance_job|
        job_template_renderer = job_template_renderers[instance_job.name]

        begin
          job_template_renderer.render(spec_object)
        rescue Exception => e
          errors.push e
        end
      end

      if errors.length > 0
        combined_errors = errors.map{|error| error.message.strip }.join("\n")
        header = "- Unable to render jobs for instance group '#{spec_object['name']}'. Errors are:"
        message = Bosh::Director::FormatterHelper.new.prepend_header_and_indent_body(header, combined_errors.strip, {:indent_by => 2})
        raise message
      end

      RenderedJobInstance.new(rendered_templates)
    end

    def validate_properties!(spec_object)
      @instance_jobs.each do |instance_job|
        job_template_renderer = job_template_renderers[instance_job.name]
        if job_template_renderer.properties_schema
          JobSchemaValidator.validate(job_name: instance_job.name, schema: job_template_renderer.properties_schema, properties: spec_object['properties'][instance_job.name])
        end
      end
    end

    private

    def job_template_renderers
      @job_template_renderers ||= @instance_jobs.reduce({}) do |renderers_hash, instance_job|
        renderers_hash[instance_job.name] = @job_template_loader.process(instance_job)
        renderers_hash
      end
    end
  end
end
