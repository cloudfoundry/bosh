require 'bosh/template/evaluation_context'
require 'bosh/template/evaluation_context'

module Bosh::Template
  module Test
    class Template
      include PropertyHelper

      def initialize(job_spec_hash, template_path)
        @job_spec_hash = job_spec_hash
        @template_path = template_path
      end

      def render(manifest_properties_hash, spec: InstanceSpec.new, consumes: [])
        spec_hash = {}
        spec_hash['properties'] = hash_with_defaults(manifest_properties_hash)
        sanitized_hash_with_spec = spec_hash.merge(spec.to_h)
        sanitized_hash_with_spec['links'] = links_hash(consumes)

        binding = Bosh::Template::EvaluationContext.new(sanitized_hash_with_spec, nil).get_binding
        raise "No such file at #{@template_path}" unless File.exist?(@template_path)
        ERB.new(File.read(@template_path), trim_mode: '-').result(binding)
      end

      private

      def hash_with_defaults(manifest_properties_hash)
        hash_properties = {}
        spec_properties = @job_spec_hash['properties']

        spec_properties.each_pair do |dotted_spec_key, property_def|
          property_val = lookup_property(manifest_properties_hash, dotted_spec_key)
          if property_val.nil? && !property_def['default'].nil?
            property_val = property_def['default']
          end
          insert_property(hash_properties, dotted_spec_key, property_val)
        end

        hash_properties
      end

      def links_hash(links)
        links_hash = {}
        known_links = []

        consumes = @job_spec_hash.fetch('consumes', [])
        consumes.each do |consume|
          known_links << consume['name']
          link = links.find {|l| l.name == consume['name']}
          links_hash[link.name] = link.to_h unless link.nil?
        end

        links.each do |link|
          unless known_links.include?(link.name)
            raise "Link '#{link.name}' is not declared as a consumed link in this job."
          end
        end

        links_hash
      end

      def insert_property(nested_hash, dotted_key, value)
        property_segments = dotted_key.split('.')
        current_level = nested_hash

        property_segments.each_with_index do |property_segment, i|
          if i == property_segments.count - 1
            current_level[property_segment] = value
          else
            current_level[property_segment] ||= {}
            current_level = current_level[property_segment]
          end
        end
      end
    end
  end
end
