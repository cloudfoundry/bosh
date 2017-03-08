module Bosh::Director::ConfigServer
  class VariablesInterpolator

    def initialize
      @config_server_client = ClientFactory.create(Bosh::Director::Config.logger).create_client
    end

    # @param [Hash] template_spec_properties Hash to be interpolated
    # @param [Hash] deployment_name The deployment context in-which the interpolation will occur
    # @param [VariableSet] variable_set The variable set which the interpolation will use. Default: nil
    # @return [Hash] A Deep copy of the interpolated template_spec_properties
    def interpolate_template_spec_properties(template_spec_properties, deployment_name, variable_set = nil)
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
          interpolated_hash = @config_server_client.interpolate(job_properties, deployment_name, variable_set)
          result[job_name] = interpolated_hash
        rescue Exception => e
          header = "- Unable to render templates for job '#{job_name}'. Errors are:"
          errors << Bosh::Director::FormatterHelper.new.prepend_header_and_indent_body(header, e.message.strip, {:indent_by => 2})
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
            interpolated_hash = @config_server_client.interpolate(link_spec['properties'], link_spec['deployment_name'], nil)
            link_spec['properties'] = interpolated_hash
          rescue Exception => e
            header = "- Unable to interpolate link '#{link_name}' properties; provided by '#{link_spec['deployment_name']}' deployment. Errors are:"
            errors << Bosh::Director::FormatterHelper.new.prepend_header_and_indent_body(header, e.message.strip, {:indent_by => 2})
          end
        end
      end

      raise errors.join("\n") unless errors.empty?

      links_spec_copy
    end

    # @param [Hash] deployment_manifest Deployment Manifest Hash to be interpolated
    # @return [Hash] A Deep copy of the interpolated manifest Hash
    def interpolate_deployment_manifest(deployment_manifest)
      ignored_subtrees = [
        ['properties'],
        ['instance_groups', Integer, 'properties'],
        ['instance_groups', Integer, 'jobs', Integer, 'properties'],
        ['instance_groups', Integer, 'jobs', Integer, 'consumes', String, 'properties'],
        ['jobs', Integer, 'properties'],
        ['jobs', Integer, 'templates', Integer, 'properties'],
        ['jobs', Integer, 'templates', Integer, 'consumes', String, 'properties'],
        ['instance_groups', Integer, 'env'],
        ['jobs', Integer, 'env'],
        ['resource_pools', Integer, 'env'],
      ]

      @config_server_client.interpolate(
        deployment_manifest,
        deployment_manifest['name'],
        nil,
        { subtrees_to_ignore: ignored_subtrees, must_be_absolute_name: false}
      )
    end

    # @param [Hash] runtime_manifest Runtime Manifest Hash to be interpolated
    # @param deployment_name [String] Name of current deployment
    # @return [Hash] A Deep copy of the interpolated manifest Hash
    def interpolate_runtime_manifest(runtime_manifest, deployment_name)
      ignored_subtrees = [
        ['addons', Integer, 'properties'],
        ['addons', Integer, 'jobs', Integer, 'properties'],
        ['addons', Integer, 'jobs', Integer, 'consumes', String, 'properties'],
      ]

      # Deployment name is passed here as nil because we required all placeholders
      # in the runtime config to be absolute, except for the properties in addons
      @config_server_client.interpolate(
        runtime_manifest,
        deployment_name,
        nil,
        { subtrees_to_ignore: ignored_subtrees, must_be_absolute_name: true }
      )
    end
  end
end

