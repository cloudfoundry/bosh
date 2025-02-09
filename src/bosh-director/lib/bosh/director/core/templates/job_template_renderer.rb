require 'bosh/director/core/templates'
require 'bosh/director/core/templates/rendered_job_template'
require 'bosh/director/core/templates/rendered_file_template'
require 'bosh/director/core/templates/template_blob_cache'
require 'bosh/template/evaluation_context'
require 'bosh/director/formatter_helper'
require 'common/deep_copy'

module Bosh::Director::Core::Templates
  class JobTemplateRenderer

    attr_reader :monit_erb, :source_erbs, :properties_schema

    def initialize(instance_job:,
                   monit_erb:,
                   source_erbs:,
                   properties_schema:,
                   logger:,
                   link_provider_intents:,
                   dns_encoder: nil)
      @links_provided = instance_job.model.provides
      @job_name = instance_job.name
      @release = instance_job.release
      @monit_erb = monit_erb
      @properties_schema = properties_schema
      @source_erbs = source_erbs
      @logger = logger
      @link_provider_intents = link_provider_intents
      @dns_encoder = dns_encoder
    end

    def render(spec)
      spec = Bosh::Common::DeepCopy.copy(spec)

      if spec['properties_need_filtering']
        spec = pick_job_properties(spec)
      end

      spec = namespace_links_to_current_job(spec)

      spec['release'] = {
        'name' => @release.name,
        'version' => @release.version
      }

      original_template_context = Bosh::Template::EvaluationContext.new(spec, @dns_encoder)

      template_context = Bosh::Common::DeepCopy.copy(original_template_context)
      monit = monit_erb.render(template_context, @logger)

      errors = []

      rendered_files = source_erbs.map do |source_erb|
        template_context = Bosh::Common::DeepCopy.copy(original_template_context) unless original_template_context == template_context

        begin
          file_contents = source_erb.render(template_context, @logger)
        rescue Exception => e
          errors.push e
        end

        RenderedFileTemplate.new(source_erb.src_filepath, source_erb.dest_filepath, file_contents)
      end

      if errors.length > 0
        combined_errors = errors.map{|error| "- #{error.message.strip}"}.join("\n")
        header = "- Unable to render templates for job '#{@job_name}'. Errors are:"
        message = Bosh::Director::FormatterHelper.new.prepend_header_and_indent_body(header, combined_errors.strip, {:indent_by => 2})

        raise message
      end

      rendered_files << RenderedFileTemplate.new('.bosh/links.json', '.bosh/links.json', links_data(spec))

      RenderedJobTemplate.new(@job_name, monit, rendered_files)
    end

    private

    def namespace_links_to_current_job(spec)
      return nil if spec.nil?

      modified_spec = spec

      if modified_spec.has_key?('links')
        if modified_spec['links'][@job_name]
          links_spec = modified_spec['links'][@job_name]
          modified_spec['links'] = links_spec
        else
          modified_spec['links'] = {}
        end
      end
      modified_spec
    end

    def pick_job_properties(spec)
      return nil if spec.nil?

      modified_spec = spec

      if modified_spec.has_key?('properties')
        if modified_spec['properties'][@job_name]
          job_properties = modified_spec['properties'][@job_name]
          modified_spec['properties'] = job_properties
        end
      end

      modified_spec
    end

    def links_data(spec)
      provider_intents = @link_provider_intents.select do |provider_intent|
        provider_intent.link_provider.instance_group == spec['name'] &&
          provider_intent.link_provider.name == @job_name
      end

      data = provider_intents.map do |provider_intent|
        {
          'name' => provider_intent.canonical_name,
          'type' => provider_intent.type,
          'group' => @dns_encoder.id_for_group_tuple(
            'link',
            provider_intent.group_name,
            spec['deployment'],
          ),
        }
      end

      JSON.pretty_generate(data.sort_by { |e| e['group'] }) + "\n"
    end
  end
end
