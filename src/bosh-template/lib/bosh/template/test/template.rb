require 'bosh/template/evaluation_context'

module Bosh::Template::Test
  class Template
    def initialize(job_spec_hash, template_path)
      @job_spec_hash = job_spec_hash
      @template_path = template_path
    end

    def render(manifest_properties_hash, spec: InstanceSpec.new, links: [])
      sanitized_hash = job_spec_adjusted_hash(manifest_properties_hash)
      sanitized_hash_with_spec = sanitized_hash.merge(spec.to_h)
      sanitized_hash_with_spec['links'] = links_hash(links)

      binding = Bosh::Template::EvaluationContext.new(sanitized_hash_with_spec, nil).get_binding
      raise "No such file at #{@template_path}" unless File.exist?(@template_path)
      ERB.new(File.read(@template_path)).result(binding)
    end

    private

    def job_spec_adjusted_hash(manifest_properties_hash)
      hash = manifest_properties_hash.clone
      hash['properties'] ||= {}
      hash_properties = hash['properties']

      spec_properties = @job_spec_hash['properties']

      spec_properties.each_pair do |k, v|
        property_val = lookup_property(hash_properties, k)
        if property_val.nil? && !v['default'].nil?
          insert_property(hash_properties, k, property_val || v['default'])
        end
      end

      hash
    end

    def links_hash(links)
      links_hash = {}

      consumes = @job_spec_hash.fetch('consumes',[])
      consumes.each do |consume|
        link = links.find {|l| l.name == consume['name']}
        links_hash[link.name] = link.to_h unless link.nil?
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

    def lookup_property(collection, name)
      return nil if collection.nil?

      keys = name.split(".")
      ref = collection

      keys.each do |key|
        ref = ref[key]
        return nil if ref.nil?
      end

      ref
    end
  end
end