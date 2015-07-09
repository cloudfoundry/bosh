module Bosh::Director
  module DeploymentPlan
    class TemplateLink < Struct.new(:name, :type)
      def self.parse(link_def)
        if link_def.is_a?(String)
          return new(link_def, link_def)
        end

        if link_def.is_a?(Hash) && link_def.has_key?('name') && link_def.has_key?('type')
          return new(link_def['name'], link_def['type'])
        end

        raise JobInvalidLinkSpec, "Link '#{link_def}' must be either string or hash with name and type"
      end

      def to_s
        "name: #{name}, type: #{type}"
      end
    end
  end
end
