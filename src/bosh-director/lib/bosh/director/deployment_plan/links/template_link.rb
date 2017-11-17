module Bosh::Director
  module DeploymentPlan
    class TemplateLink < Struct.new(:name, :type, :optional, :shared, :original_name)
      def self.parse(kind, link_def)
        if kind == "consumes"
          return self.parse_consumes_link(link_def)
        elsif kind == "provides"
          return self.parse_provides_link(link_def)
        end
      end

      def self.parse_consumes_link(link_def)
        if link_def.is_a?(Hash) && link_def.has_key?('type') && link_def.has_key?('name')
          if link_def.has_key?('from')
            return new(link_def['from'].split(".")[-1], link_def['type'], link_def['optional'] || false, false, link_def['name'])
          else
            return new(link_def['name'], link_def['type'], link_def['optional'] || false, false, link_def['name'])
          end
        end
        raise JobInvalidLinkSpec, "Link '#{link_def}' must be a hash with name and type"
      end

      def self.parse_provides_link(link_def)
        if link_def.is_a?(Hash) && link_def.has_key?('type') && link_def.has_key?('name')
          if link_def.has_key?('optional')
            raise JobInvalidLinkSpec, "Link '#{link_def['name']}' of type '#{link_def['type']}' is a provides link, not allowed to have 'optional' key"
          elsif link_def.has_key?('as')
            return new(link_def['as'], link_def['type'], false, link_def['shared'] || false, link_def['name'])
          else
            return new(link_def['name'], link_def['type'], false, link_def['shared'] || false)
          end
        end
        raise JobInvalidLinkSpec, "Link '#{link_def}' must be a hash with name and type"
      end

      def to_s
        "name: #{name}, type: #{type}, shared: #{shared || false}"
      end
    end
  end
end
