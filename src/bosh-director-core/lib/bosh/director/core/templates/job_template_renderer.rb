require 'bosh/director/core/templates'
require 'bosh/director/core/templates/rendered_job_template'
require 'bosh/director/core/templates/rendered_file_template'
require 'bosh/template/evaluation_context'
require 'bosh/director/formatter_helper'
require 'common/deep_copy'

module Bosh::Director::Core::Templates
  class JobTemplateRenderer

    attr_reader :monit_erb, :source_erbs

    def initialize(name, template_name, monit_erb, source_erbs, logger, dns_encoder = nil)
      @name = name
      @template_name = template_name
      @monit_erb = monit_erb
      @source_erbs = source_erbs
      @logger = logger
      @dns_encoder = dns_encoder
    end

    def render(spec)
      if spec['properties_need_filtering']
        spec = remove_unused_properties(spec)
      end

      spec = namespace_links_to_current_job(spec)

      template_context = Bosh::Template::EvaluationContext.new(Bosh::Common::DeepCopy.copy(spec), @dns_encoder)
      monit = monit_erb.render(template_context, @logger)

      errors = []

      rendered_files = source_erbs.map do |source_erb|
        template_context = Bosh::Template::EvaluationContext.new(Bosh::Common::DeepCopy.copy(spec), @dns_encoder)

        begin
          file_contents = source_erb.render(template_context, @logger)
        rescue Exception => e
          errors.push e
        end

        RenderedFileTemplate.new(source_erb.src_name, source_erb.dest_name, file_contents)
      end

      if errors.length > 0
        combined_errors = errors.map{|error| "- #{error.message.strip}"}.join("\n")
        header = "- Unable to render templates for job '#{@name}'. Errors are:"
        message = Bosh::Director::FormatterHelper.new.prepend_header_and_indent_body(header, combined_errors.strip, {:indent_by => 2})

        raise message
      end

      RenderedJobTemplate.new(@name, monit, rendered_files)
    end

    private

    def namespace_links_to_current_job(spec)
      if spec.nil?
        return nil
      end

      modified_spec = Bosh::Common::DeepCopy.copy(spec)

      if modified_spec.has_key?('links')
        if modified_spec['links'][@template_name]
          links_spec = modified_spec['links'][@template_name]
          modified_spec['links'] = links_spec
        elsif
          modified_spec['links'] = {}
        end
      end
      modified_spec
    end

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
