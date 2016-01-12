module Bosh::Director
  module DeploymentPlan
    class TemplateLink < Struct.new(:name, :type)
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
            return new(link_def['from'].split(".")[-1], link_def['type'])
          else
            return new(link_def['name'], link_def['type'])
          end
        end
        raise JobInvalidLinkSpec, "Link '#{link_def}' must be a hash with name and type"
      end

      def self.parse_provides_link(link_def)
        if link_def.is_a?(Hash) && link_def.has_key?('type') && link_def.has_key?('name')
          if link_def.has_key?('as')
            return new(link_def['as'], link_def['type'])
          else
            return new(link_def['name'], link_def['type'])
          end
        end
        raise JobInvalidLinkSpec, "Link '#{link_def}' must be a hash with name and type"
      end

      def to_s
        "name: #{name}, type: #{type}"
      end
    end
  end
end
