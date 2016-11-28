require 'bosh/director/core/templates'
require 'bosh/director/core/templates/rendered_job_template'
require 'bosh/director/core/templates/rendered_file_template'
require 'bosh/template/evaluation_context'
require 'common/deep_copy'

module Bosh::Director::Core::Templates
  class JobTemplateRenderer
    attr_reader :monit_erb, :source_erbs

    def initialize(name, template_name, monit_erb, source_erbs, logger)
      @name = name
      @template_name = template_name
      @monit_erb = monit_erb
      @source_erbs = source_erbs
      @logger = logger
    end

    def render(spec)
      if spec['properties_need_filtering']
        spec = remove_unused_properties(spec)
      end

      template_context = Bosh::Template::EvaluationContext.new(Bosh::Common::DeepCopy.copy(spec))
      monit = monit_erb.render(template_context, @logger)

      errors = []

      rendered_files = source_erbs.map do |source_erb|
        template_context = Bosh::Template::EvaluationContext.new(Bosh::Common::DeepCopy.copy(spec))

        begin
          file_contents = source_erb.render(template_context, @logger)
        rescue Exception => e
          errors.push e
        end

        RenderedFileTemplate.new(source_erb.src_name, source_erb.dest_name, file_contents)
      end

      if errors.length > 0
        message = "Unable to render templates for job '#{@name}'. Errors are:"

        errors.each do |e|
          message = "#{message}\n   - #{e.message.gsub(/\n/, "\n  ")}"
        end

        raise message
      end

      RenderedJobTemplate.new(@name, monit, rendered_files)
    end

    private

    def remove_unused_properties(spec)
      if spec.nil?
        return nil
      end

      modified_spec = Bosh::Common::DeepCopy.copy(spec)

      if modified_spec.has_key?('properties')
        if modified_spec['properties'][@template_name]
          properties_template = modified_spec['properties'][@template_name]
          modified_spec['properties'] = properties_template
        end
      end

      modified_spec
    end

  end
end