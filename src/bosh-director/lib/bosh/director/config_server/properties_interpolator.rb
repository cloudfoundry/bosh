module Bosh::Director::ConfigServer
  class PropertiesInterpolator
    include Bosh::Director::FormatterHelper

    def initialize(deployment_name)
      @config_server_client = ClientFactory.create(Bosh::Director::Config.logger).create_client(deployment_name)
    end

    # @param [Hash] template_spec_properties Hash to be interpolated
    # @param [Hash] deployment_name The deployment context in-which the interpolation will occur
    # @return [Hash] A Deep copy of the interpolated template_spec_properties
    def interpolate_template_spec_properties(template_spec_properties, deployment_name)
      if template_spec_properties.nil?
        return template_spec_properties
      end

      if deployment_name.nil?
        raise Bosh::Director::ConfigServerDeploymentNameMissing, "Deployment name missing while interpolating jobs' properties"
      end

      result = {}
      errors = []

      template_spec_properties.each do |job_name, job_properties|
        begin
          interpolated_hash = @config_server_client.interpolate(job_properties, deployment_name)
          result[job_name] = interpolated_hash
        rescue Exception => e
          errors << prepend_header_and_indent_body("- Unable to render templates for job '#{job_name}'. Errors are:", e.message.strip, {:indent_by => 2})
        end
      end

      raise errors.join("\n") unless errors.empty?

      result
    end

    # Note: The links properties will be interpolated in the context of the deployment that provides them
    # @param [Hash] links_spec Hash to be interpolated
    # @return [Hash] A Deep copy of the interpolated links_spec. Only the properties for the links will be interpolated
    def interpolate_link_spec_properties(links_spec)
      if links_spec.nil?
        return links_spec
      end

      links_spec_copy = Bosh::Common::DeepCopy.copy(links_spec)
      errors = []

      links_spec_copy.each do |link_name, link_spec|
        if link_spec.has_key?('properties') && !link_spec['properties'].nil?
          begin
            interpolated_hash = @config_server_client.interpolate(link_spec['properties'], link_spec['deployment_name'])
            link_spec['properties'] = interpolated_hash
          rescue Exception => e
            header = "- Unable to interpolate link '#{link_name}' properties; provided by '#{link_spec['deployment_name']}' deployment. Errors are:"
            errors << prepend_header_and_indent_body(header, e.message.strip, {:indent_by => 2})
          end
        end
      end

      raise errors.join("\n") unless errors.empty?

      links_spec_copy
    end

  end
end

