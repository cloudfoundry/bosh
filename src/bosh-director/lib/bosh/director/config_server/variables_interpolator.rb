module Bosh::Director::ConfigServer
  class VariablesInterpolator

    def initialize
      @config_server_client = ClientFactory.create(Bosh::Director::Config.logger).create_client
    end

    # @param [Hash] template_spec_properties Hash to be interpolated
    # @param [Hash] deployment_name The deployment context in-which the interpolation will occur
    # @param [VariableSet] variable_set The variable set which the interpolation will use.
    # @return [Hash] A Deep copy of the interpolated template_spec_properties
    def interpolate_template_spec_properties(template_spec_properties, deployment_name, variable_set)
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
          interpolated_hash = @config_server_client.interpolate(job_properties, variable_set)
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
    # @param [Bosh::Director::Models::VariableSet] consumer_variable_set
    # @return [Hash] A Deep copy of the interpolated links_spec. Only the properties for the links will be interpolated
    def interpolate_link_spec_properties(links_spec, consumer_variable_set)
      if links_spec.nil?
        return links_spec
      end

      errors = []
      consumer_deployment_name = consumer_variable_set.deployment.name
      links_spec_copy = Bosh::Common::DeepCopy.copy(links_spec)

      links_spec_copy.each do |link_name, link_spec|
        if link_spec.has_key?('properties') && !link_spec['properties'].nil?
          begin
            provider_deployment_name = link_spec['deployment_name']
            if provider_deployment_name == consumer_deployment_name
              interpolated_link_properties = @config_server_client.interpolate(link_spec['properties'], consumer_variable_set)
              link_spec['properties'] = interpolated_link_properties
            else
              provider_deployment = get_deployment_by_name(provider_deployment_name)
              provider_variable_set = provider_last_successful_variable_set(provider_deployment)

              interpolated_link_properties = @config_server_client.interpolate_cross_deployment_link(link_spec['properties'], consumer_variable_set, provider_variable_set)
              link_spec['properties'] = interpolated_link_properties
            end
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

      deployment_model = get_deployment_by_name(deployment_manifest['name'])

      @config_server_client.interpolate(
        deployment_manifest,
        deployment_model.current_variable_set,
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

      deployment_model = get_deployment_by_name(deployment_name)

      @config_server_client.interpolate(
        runtime_manifest,
        deployment_model.current_variable_set,
        { subtrees_to_ignore: ignored_subtrees, must_be_absolute_name: true }
      )
    end

    # @param [Hash] cloud_manifest Cloud Manifest Hash to be interpolated
    # @param deployment_name [String] Name of current deployment
    # @return [Hash] A Deep copy of the interpolated manifest Hash
    def interpolate_cloud_manifest(cloud_manifest, deployment_name)
      ignored_subtrees = [
          ['azs', Integer, 'cloud_properties', String],
          ['networks', Integer, 'cloud_properties', String],
          ['networks', Integer, 'subnets', Integer, 'cloud_properties', String],
          ['vm_types', Integer, 'cloud_properties', String],
          ['vm_extensions', Integer, 'cloud_properties', String],
          ['disk_types', Integer, 'cloud_properties', String],
          ['compilation', 'cloud_properties', String]
      ]

      variable_set = nil
      unless deployment_name.nil?
        deployment_model = get_deployment_by_name(deployment_name)
        variable_set = deployment_model.current_variable_set
      end

      # must_be_absolute_name is true because we require all placeholders
      # in the cloud config to be absolute
      @config_server_client.interpolate(
          cloud_manifest,
          variable_set,
          { subtrees_to_ignore: ignored_subtrees, must_be_absolute_name: true }
      )
    end

    # @param [Hash] cpi_manifest CPI Manifest Hash to be interpolated
    # @return [Hash] A Deep copy of the interpolated manifest Hash
    def interpolate_cpi_config(cpi_config)
      ignored_subtrees = [
          ['name'],
          ['type']
      ]
      @config_server_client.interpolate(
          cpi_config,
          nil,
          { subtrees_to_ignore: ignored_subtrees, must_be_absolute_name: true }
      )
    end

    private

    def get_deployment_by_name(name)
      deployment = Bosh::Director::Models::Deployment[name: name]
      if deployment.nil?
        raise Bosh::Director::DeploymentNotFound, "- Deployment '#{name}' doesn't exist"
      end
      deployment
    end

    def provider_last_successful_variable_set(deployment)
      variable_set = deployment.last_successful_variable_set
      if variable_set.nil?
        raise Bosh::Director::VariableSetNotFound, "- Cannot consume properties from deployment '#{deployment.name}'. It was never successfully deployed."
      end
      variable_set
    end
  end
end

