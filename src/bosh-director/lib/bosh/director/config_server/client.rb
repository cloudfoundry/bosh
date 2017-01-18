require 'bosh/director/config_server/config_server_helper'

module Bosh::Director::ConfigServer
  class EnabledClient
    include ConfigServerHelper

    def initialize(http_client, director_name, logger)
      @config_server_http_client = http_client
      @director_name = director_name
      @deep_hash_replacer = DeepHashReplacement.new
      @logger = logger
    end

    # @param [Hash] src Hash to be interpolated
    # @param [String] deployment_name The deployment context in-which the interpolation
    # will occur (used mostly for links properties interpolation since they will be interpolated in
    # the context of the deployment providing these links)
    # @param [Hash] options Additional options
    #   Options include:
    #   - 'subtrees_to_ignore': [Array] Array of paths that should not be interpolated in src
    #   - 'must_be_absolute_name': [Boolean] Flag to check if all the placeholders start with '/'
    # @return [Hash] A Deep copy of the interpolated src Hash
    def interpolate(src, deployment_name, options = {})
      subtrees_to_ignore = options.fetch(:subtrees_to_ignore, [])
      must_be_absolute_name = options.fetch(:must_be_absolute_name, false)

      placeholders_paths = @deep_hash_replacer.placeholders_paths(src, subtrees_to_ignore)
      placeholders_list = placeholders_paths.map { |c| c['placeholder'] }.uniq

      retrieved_config_server_values = fetch_names_values(placeholders_list, deployment_name, must_be_absolute_name)

      @deep_hash_replacer.replace_placeholders(src, placeholders_paths, retrieved_config_server_values)
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

      interpolate(
        deployment_manifest,
        deployment_manifest['name'],
        { subtrees_to_ignore: ignored_subtrees, must_be_absolute_name: false }
      )
    end

    # @param [Hash] runtime_manifest Runtime Manifest Hash to be interpolated
    # @return [Hash] A Deep copy of the interpolated manifest Hash
    def interpolate_runtime_manifest(runtime_manifest)
      ignored_subtrees = [
        ['addons', Integer, 'properties'],
        ['addons', Integer, 'jobs', Integer, 'properties'],
        ['addons', Integer, 'jobs', Integer, 'consumes', String, 'properties'],
      ]

      # Deployment name is passed here as nil because we required all placeholders
      # in the runtime config to be absolute, except for the properties in addons
      interpolate(
        runtime_manifest,
        nil,
        { subtrees_to_ignore: ignored_subtrees, must_be_absolute_name: true }
      )
    end

    # Refer to unit tests for full understanding of this method
    # @param [Object] provided_prop property value
    # @param [Object] default_prop property value
    # @param [String] type of property
    # @param [String] deployment_name
    # @param [Hash] options hash containing extra options when needed
    # @return [Object] either the provided_prop or the default_prop
    def prepare_and_get_property(provided_prop, default_prop, type, deployment_name, options = {})
      if provided_prop.nil?
        result = default_prop
      else
        if is_full_placeholder?(provided_prop)
          extracted_name = add_prefix_if_not_absolute(
            extract_placeholder_name(provided_prop),
            @director_name,
            deployment_name
          )
          extracted_name = extracted_name.split('.').first

          if name_exists?(extracted_name)
            result = provided_prop
          else
            if default_prop.nil?
              if type == 'certificate'
                generate_certificate(extracted_name, deployment_name, options)
              elsif type
                generate_value_and_record_event(extracted_name, type, deployment_name, {})
              end
              result = provided_prop
            else
              result = default_prop
            end
          end
        else
          result = provided_prop
        end
      end
      result
    end

    # @param [DeploymentPlan::Variables] variables Object representing variables passed by the user
    # @param [String] deployment_name
    def generate_values(variables, deployment_name)
      variables.spec.each do |variable|
        variable_name = variable['name']
        validate_variable_name(variable_name)

        constructed_name = add_prefix_if_not_absolute(
          variable_name,
          @director_name,
          deployment_name
        )

        generate_value_and_record_event(constructed_name, variable['type'], deployment_name, variable['options'])
      end
    end

    private

    def get_value_for_name(name)
      name_tokens = name.split('.')
      name_root = name_tokens.shift
      response = @config_server_http_client.get(name_root)

      if response.kind_of? Net::HTTPOK
        begin
          response_body = JSON.parse(response.body)
        rescue JSON::ParserError
          raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Invalid JSON response"
        end

        response_data = response_body['data']

        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data to be an array" if !response_data.is_a?(Array)
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data to be non empty array" if response_data.empty?
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data[0] to have key 'value'" if !response_data[0].has_key?('value')

        result = response_data[0]['value']

        name_tokens.each_with_index do |value, index|
          if !result.is_a?(Hash) || !result.has_key?(value)
            parent = index > 0 ? ([name_root] + name_tokens[0..(index - 1)]).join('.') : name_root
            raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected parent '#{parent}' to be a hash" if !result.is_a?(Hash)
            raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected parent '#{parent}' hash to have key '#{value}'" if !result.has_key?(value)
          end

          result = result[value]
        end

        return result

      elsif response.kind_of? Net::HTTPNotFound
        raise Bosh::Director::ConfigServerMissingName, "Failed to find variable '#{name_root}' from config server: HTTP code '404'"

      else
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: HTTP code '#{response.code}'"
      end
    end

    def name_exists?(name)
      get_value_for_name(name)
    rescue Bosh::Director::ConfigServerMissingName
      false
    end

    def fetch_names_values(placeholders, deployment_name, must_be_absolute_name)

      errors = []
      config_values = {}

      validate_absolute_names(placeholders) if must_be_absolute_name

      placeholders.each do |placeholder|
        name = add_prefix_if_not_absolute(
          extract_placeholder_name(placeholder),
          @director_name,
          deployment_name
        )

        begin
          config_values[placeholder] = get_value_for_name(name)
        rescue Bosh::Director::ConfigServerFetchError, Bosh::Director::ConfigServerMissingName => e
          errors << e
        end
      end

      if errors.length > 0
        message = errors.map{|error| "- #{error.message}"}.join("\n")
        raise Bosh::Director::ConfigServerFetchError, message
      end

      config_values
    end

    def generate_value(name, type, options)
      parameters = options.nil? ? {} : options

      request_body = {
        'name' => name,
        'type' => type,
        'parameters' => parameters
      }

      response = @config_server_http_client.post(request_body)

      unless response.kind_of? Net::HTTPSuccess
        @logger.error("Config server error while generating value for '#{name}': #{response.code}  #{response.message}. Request body sent: #{request_body}")
        raise Bosh::Director::ConfigServerGenerationError, "Config Server failed to generate value for '#{name}' with type '#{type}'. Error: '#{response.message}'"
      end

      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise Bosh::Director::ConfigServerGenerationError,"Config Server returned a NON-JSON body while generating value for '#{name}' with type '#{type}'"
      end
    end

    def generate_certificate(name, deployment_name, options)
      dns_record_names = options[:dns_record_names]

      certificate_options = {
        'common_name' => dns_record_names.first,
        'alternative_names' => dns_record_names
      }

      generate_value_and_record_event(name, 'certificate', deployment_name, certificate_options)
    end

    def add_event(options)
      Bosh::Director::Config.current_job.event_manager.create_event(
        {
          user:        Bosh::Director::Config.current_job.username,
          object_type: 'variable',
          task:        Bosh::Director::Config.current_job.task_id,
          action:      options.fetch(:action),
          object_name: options.fetch(:object_name),
          deployment:  options.fetch(:deployment_name),
          context:     options.fetch(:context, {}),
          error:       options.fetch(:error, nil)
        })
    end

    def generate_value_and_record_event(variable_name, variable_type, deployment_name, options)
      begin
        result = generate_value(variable_name, variable_type, options)
        add_event(
          :action => 'create',
          :deployment_name => deployment_name,
          :object_name => variable_name,
          :context => {'name' => result['name'], 'id' => result['id']}
        )
        result
      rescue Exception => e
        add_event(
          :action => 'create',
          :deployment_name => deployment_name,
          :object_name => variable_name,
          :error => e
        )
        raise e
      end
    end
  end

  class DisabledClient
    def interpolate(src, deployment_name, options={})
      Bosh::Common::DeepCopy.copy(src)
    end

    def interpolate_deployment_manifest(manifest)
      Bosh::Common::DeepCopy.copy(manifest)
    end

    def interpolate_runtime_manifest(manifest)
      Bosh::Common::DeepCopy.copy(manifest)
    end

    def prepare_and_get_property(manifest_provided_prop, default_prop, type, deployment_name, options = {})
      manifest_provided_prop.nil? ? default_prop : manifest_provided_prop
    end

    def generate_values(variables, deployment_name)
      # do nothing. When config server is not enabled, nothing to do
    end
  end
end
