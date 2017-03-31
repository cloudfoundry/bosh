require 'bosh/director/config_server/config_server_helper'

module Bosh::Director::ConfigServer
  class EnabledClient
    def initialize(http_client, director_name, logger)
      @config_server_http_client = http_client
      @director_name = director_name
      @deep_hash_replacer = DeepHashReplacement.new
      @deployment_lookup = Bosh::Director::Api::DeploymentLookup.new
      @logger = logger
    end

    # @param [Hash] src Hash to be interpolated
    # @param [String] deployment_name The deployment context in-which the interpolation
    # will occur (used mostly for links properties interpolation since they will be interpolated in
    # the context of the deployment providing these links)
    # @param [VariableSet] variable_set The variable set to use with interpolation. If 'nil' it will
    # use the default variable set from deployment.
    # @param [Hash] options Additional options
    #   Options include:
    #   - 'subtrees_to_ignore': [Array] Array of paths that should not be interpolated in src
    #   - 'must_be_absolute_name': [Boolean] Flag to check if all the placeholders start with '/'
    # @return [Hash] A Deep copy of the interpolated src Hash
    def interpolate(src, deployment_name, variable_set, options = {})
      subtrees_to_ignore = options.fetch(:subtrees_to_ignore, [])
      must_be_absolute_name = options.fetch(:must_be_absolute_name, false)

      variable_set = variable_set || @deployment_lookup.by_name(deployment_name).current_variable_set

      placeholders_paths = @deep_hash_replacer.placeholders_paths(src, subtrees_to_ignore)
      placeholders_list = placeholders_paths.flat_map { |c| c['placeholders'] }.uniq

      retrieved_config_server_values = fetch_values(placeholders_list, deployment_name, variable_set, must_be_absolute_name)

      @deep_hash_replacer.replace_placeholders(src, placeholders_paths, retrieved_config_server_values)
    end

    # @param [Hash] link_properties_hash Link spec properties to be interpolated
    # @param [VariableSet] consumer_variable_set The variable set of the consumer deployment
    # @param [VariableSet] provider_variable_set The variable set of the provider deployment
    # @return [Hash] A Deep copy of the interpolated links spec
    def interpolate_cross_deployment_link(link_properties_hash, consumer_variable_set, provider_variable_set)
      return link_properties_hash if link_properties_hash.nil?
      raise "Unable to interpolate cross deployment link properties. Expected a 'Hash', got '#{link_properties_hash.class}'" unless link_properties_hash.is_a?(Hash)

      placeholders_paths = @deep_hash_replacer.placeholders_paths(link_properties_hash)
      placeholders_list = placeholders_paths.flat_map { |c| c['placeholders'] }.uniq

      retrieved_config_server_values = resolve_cross_deployments_variables(placeholders_list, consumer_variable_set, provider_variable_set)

      @deep_hash_replacer.replace_placeholders(link_properties_hash, placeholders_paths, retrieved_config_server_values)
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
        if ConfigServerHelper.is_full_placeholder?(provided_prop)
          extracted_name = ConfigServerHelper.add_prefix_if_not_absolute(
            ConfigServerHelper.extract_placeholder_name(provided_prop),
            @director_name,
            deployment_name
          )
          extracted_name = extracted_name.split('.').first

          if name_exists?(extracted_name)
            result = provided_prop
          else
            if default_prop.nil?
              variable_set = @deployment_lookup.by_name(deployment_name).current_variable_set

              if type == 'certificate'
                generate_certificate(extracted_name, deployment_name, variable_set, options)
              elsif type
                generate_value_and_record_event(extracted_name, type, deployment_name, variable_set, {})
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
      current_variable_set = @deployment_lookup.by_name(deployment_name).current_variable_set

      variables.spec.each do |variable|
        variable_name = variable['name']
        ConfigServerHelper.validate_variable_name(variable_name)

        constructed_name = ConfigServerHelper.add_prefix_if_not_absolute(
          variable_name,
          @director_name,
          deployment_name
        )

        if variable['type'] == 'certificate' && variable['options'] && variable['options']['ca']
          variable['options']['ca'] = ConfigServerHelper.add_prefix_if_not_absolute(
              variable['options']['ca'],
              @director_name,
              deployment_name
          )
        end

        generate_value_and_record_event(constructed_name, variable['type'], deployment_name, current_variable_set, variable['options'])
      end
    end

    private

    def fetch_values(variables, deployment_name, variable_set, must_be_absolute_name)
      ConfigServerHelper.validate_absolute_names(variables) if must_be_absolute_name

      errors = []
      config_values = {}

      variables.each do |variable|
        name = ConfigServerHelper.add_prefix_if_not_absolute(
          ConfigServerHelper.extract_placeholder_name(variable),
          @director_name,
          deployment_name
        )
        begin
          name_root = get_name_root(name)

          saved_variable_mapping = Bosh::Director::Models::Variable[variable_set_id: variable_set.id, variable_name: name_root]

          if saved_variable_mapping.nil?
            raise Bosh::Director::ConfigServerInconsistentVariableState, "Variable #{name_root} was previously defined, but does not exist on the director" unless variable_set.writable

            fetched_variable_from_cfg_srv = get_variable_by_name(name)

            begin
              save_variable(name_root, variable_set, fetched_variable_from_cfg_srv)
              config_values[variable] = extract_variable_value(name, fetched_variable_from_cfg_srv)
            rescue Sequel::UniqueConstraintViolation
              saved_variable_mapping = Bosh::Director::Models::Variable[variable_set: variable_set, variable_name: name_root]
              config_values[variable] = get_value_by_id(saved_variable_mapping.variable_name, saved_variable_mapping.variable_id)
            end

          else
            config_values[variable] = get_value_by_id(name, saved_variable_mapping.variable_id)
          end
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

    def resolve_cross_deployments_variables(variables, consumer_variable_set, provider_variable_set)
      provider_deployment_name = provider_variable_set.deployment.name

      errors = []
      config_values = {}

      variables.each do |variable|
        raw_variable_name = ConfigServerHelper.add_prefix_if_not_absolute(
          ConfigServerHelper.extract_placeholder_name(variable),
          @director_name,
          provider_deployment_name
        )

        variable_composed_name = get_name_root(raw_variable_name)
        consumer_variable_model = consumer_variable_set.find_variable_by_name(variable_composed_name)

        begin
          if !consumer_variable_model.nil?
            variable_id_to_fetch = consumer_variable_model.variable_id
          elsif !consumer_variable_set.writable
            consumer_deployment_name = consumer_variable_set.deployment.name
            raise Bosh::Director::ConfigServerInconsistentVariableState, "Expected variable '#{variable_composed_name}' to be already versioned in deployment '#{consumer_deployment_name}'"
          else
            provider_variable_model = provider_variable_set.find_variable_by_name(variable_composed_name)
            raise Bosh::Director::ConfigServerInconsistentVariableState, "Expected variable '#{variable_composed_name}' to be already versioned in link provider deployment '#{provider_deployment_name}'" if provider_variable_model.nil?

            variable_id = provider_variable_model.variable_id
            variable_name = provider_variable_model.variable_name

            begin
              consumer_variable_set.add_variable(variable_name: variable_name, variable_id: variable_id)
            rescue Sequel::UniqueConstraintViolation
              @logger.debug("Variable '#{variable_name}' was already added to consumer variable set '#{consumer_variable_set.id}'")
            end

            variable_id_to_fetch = provider_variable_model.variable_id
          end

          config_values[variable] = get_value_by_id(raw_variable_name, variable_id_to_fetch)
        rescue Bosh::Director::ConfigServerInconsistentVariableState, Bosh::Director::ConfigServerFetchError, Bosh::Director::ConfigServerMissingName => e
          errors << e
        end
      end

      if errors.length > 0
        message = errors.map{|error| "- #{error.message}"}.join("\n")
        raise Bosh::Director::ConfigServerFetchError, message
      end

      config_values
    end

    def get_value_by_id(name, id)
      name_root = get_name_root(name)
      response = @config_server_http_client.get_by_id(id)

      response_data = nil
      if response.kind_of? Net::HTTPOK
        begin
          response_data = JSON.parse(response.body)
        rescue JSON::ParserError
          raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Invalid JSON response"
        end
      elsif response.kind_of? Net::HTTPNotFound
        raise Bosh::Director::ConfigServerMissingName, "Failed to find variable '#{name_root}' from config server: HTTP code '404'"
      else
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: HTTP code '#{response.code}'"
      end

      extract_variable_value(name, response_data)
    end

    def extract_variable_value(name, var)
      name_tokens = name.split('.')
      name_root = name_tokens.shift
      raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data[0] to have key 'value'" unless var.has_key?('value')

      value = var['value']

      name_tokens.each_with_index do |token, index|
        parent = index > 0 ? ([name_root] + name_tokens[0..(index - 1)]).join('.') : name_root
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected parent '#{parent}' to be a hash" unless value.is_a?(Hash)
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected parent '#{parent}' hash to have key '#{token}'" unless value.has_key?(token)

        value = value[token]
      end

      value
    end

    def get_variable_by_name(name)
      name_root = get_name_root(name)

      response = @config_server_http_client.get(name_root)

      if response.kind_of? Net::HTTPOK
        begin
          response_body = JSON.parse(response.body)
        rescue JSON::ParserError
          raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Invalid JSON response"
        end

        response_data = response_body['data']

        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data to be an array" unless response_data.is_a?(Array)
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data to be non empty array" if response_data.empty?

        response_data[0]
      elsif response.kind_of? Net::HTTPNotFound
        raise Bosh::Director::ConfigServerMissingName, "Failed to find variable '#{name_root}' from config server: HTTP code '404'"
      else
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: HTTP code '#{response.code}'"
      end
    end

    def name_exists?(name)
      get_variable_by_name(name)
    rescue Bosh::Director::ConfigServerMissingName
      false
    end

    def save_variable(name_root, variable_set, var)
      raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data[0] to have key 'id'" unless var.has_key?('id')
      variable_set.add_variable(variable_name: name_root, variable_id: var['id'])
    end

    def generate_value(name, type, variable_set, options)
      parameters = options.nil? ? {} : options

      request_body = {
        'name' => name,
        'type' => type,
        'parameters' => parameters
      }

      raise Bosh::Director::ConfigServerInconsistentVariableState, "Variable #{get_name_root(name)} was previously defined, but does not exist on the director" unless variable_set.writable

      response = @config_server_http_client.post(request_body)
      unless response.kind_of? Net::HTTPSuccess
        @logger.error("Config server error while generating value for '#{name}': #{response.code}  #{response.message}. Request body sent: #{request_body}")
        raise Bosh::Director::ConfigServerGenerationError, "Config Server failed to generate value for '#{name}' with type '#{type}'. Error: '#{response.message}'"
      end

      response_body = nil
      begin
        response_body = JSON.parse(response.body)
      rescue JSON::ParserError
        raise Bosh::Director::ConfigServerGenerationError, "Config Server returned a NON-JSON body while generating value for '#{get_name_root(name)}' with type '#{type}'"
      end

      begin
        save_variable(get_name_root(name), variable_set, response_body)
      rescue Sequel::UniqueConstraintViolation
        @logger.debug("variable '#{get_name_root(name)}' was already added to set '#{variable_set.id}'")
      end

      response_body
    end

    def generate_certificate(name, deployment_name, variable_set, options)
      dns_record_names = options[:dns_record_names]

      certificate_options = {
        'common_name' => dns_record_names.first,
        'alternative_names' => dns_record_names
      }

      generate_value_and_record_event(name, 'certificate', deployment_name, variable_set, certificate_options)
    end

    def get_name_root(variable_name)
      name_tokens = variable_name.split('.')
      name_tokens[0]
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

    def generate_value_and_record_event(variable_name, variable_type, deployment_name, variable_set, options)
      begin
        result = generate_value(variable_name, variable_type, variable_set, options)
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
    def interpolate(src, deployment_name, variable_set, options={})
      Bosh::Common::DeepCopy.copy(src)
    end

    def interpolate_cross_deployment_link(link_spec, consumer_variable_set, provider_variable_set)
      Bosh::Common::DeepCopy.copy(link_spec)
    end

    def prepare_and_get_property(manifest_provided_prop, default_prop, type, deployment_name, options = {})
      manifest_provided_prop.nil? ? default_prop : manifest_provided_prop
    end

    def generate_values(variables, deployment_name)
      # do nothing. When config server is not enabled, nothing to do
    end
  end
end
