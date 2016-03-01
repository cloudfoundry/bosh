require 'bosh/director/core/templates'
require 'bosh/director/core/templates/rendered_job_template'
require 'bosh/director/core/templates/rendered_file_template'
require 'bosh/template/evaluation_context'
require 'common/deep_copy'

module Bosh::Director::Core::Templates
  class JobTemplateRenderer
    attr_reader :monit_erb, :source_erbs

    def initialize(name, monit_erb, source_erbs, logger)
      @name = name
      @monit_erb = monit_erb
      @source_erbs = source_erbs
      @logger = logger
    end

    def render(spec)
      template_context = Bosh::Template::EvaluationContext.new(adjust_template_properties(spec,@name))

      monit = monit_erb.render(template_context, @logger)

      errors = []

      rendered_files = source_erbs.map do |source_erb|
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

    # This method will check if the current template has any properties that were
    # defined at the template level in the deployment manifest; if yes, it will make
    # a deep copy of the spec and change the spec.properties to <current-template>.template_scoped_properties.
    # This is due to the requirement that limits the available properties for a template
    # by the properties defined in the template scope in the deployment manifest, if they exist.
    # We make a deep copy of the spec to be safe, as we are modifying it.
    def adjust_template_properties(spec, current_template_name)
      result = spec
      if spec['job'].is_a?(Hash) && !spec['job']['templates'].nil?
        current_template = spec['job']['templates'].find {|template| template['name'] == current_template_name }

        if !current_template['template_scoped_properties'].nil?
          # Make a deep copy of the spec and replace the properties with
          # the specific template properties.
          altered_spec = Bosh::Common::DeepCopy.copy(spec)
          altered_spec['properties'] = Bosh::Common::DeepCopy.copy(
              current_template['template_scoped_properties']
          )
          result = altered_spec
        end
      end
      result
    end

  end
end
