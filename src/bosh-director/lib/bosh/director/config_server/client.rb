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

    # @param [Hash] raw_hash Hash to be interpolated. This method only supports Absolute Names.
    # @param [Hash] options Additional options
    #   Options include:
    #   - 'subtrees_to_ignore': [Array] Array of paths that should not be interpolated in src
    # @return [Hash] A Deep copy of the interpolated src Hash
    def interpolate(raw_hash, options = {})
      return raw_hash if raw_hash.nil?
      raise "Unable to interpolate provided object. Expected a 'Hash', got '#{raw_hash.class}'" unless raw_hash.is_a?(Hash)

      subtrees_to_ignore = options.fetch(:subtrees_to_ignore, [])

      variables_paths = @deep_hash_replacer.variables_path(raw_hash, subtrees_to_ignore)
      variables_list = variables_paths.flat_map { |c| c['variables'] }.uniq

      retrieved_config_server_values = fetch_values_with_latest(variables_list)

      @deep_hash_replacer.replace_variables(raw_hash, variables_paths, retrieved_config_server_values)
    end

    # @param [Hash] raw_hash Hash to be interpolated
    # @param [VariableSet] variable_set The variable set to use with interpolation.
    # @param [Hash] options Additional options
    #   Options include:
    #   - 'subtrees_to_ignore': [Array] Array of paths that should not be interpolated in src
    #   - 'must_be_absolute_name': [Boolean] Flag to check if all the variables start with '/'
    # @return [Hash] A Deep copy of the interpolated src Hash
    def interpolate_with_versioning(raw_hash, variable_set, options = {})
      return raw_hash if raw_hash.nil?
      raise "Unable to interpolate provided object. Expected a 'Hash', got '#{raw_hash.class}'" unless raw_hash.is_a?(Hash)
      raise "Variable Set cannot be nil." if variable_set.nil?

      subtrees_to_ignore = options.fetch(:subtrees_to_ignore, [])

      variables_paths = @deep_hash_replacer.variables_path(raw_hash, subtrees_to_ignore)
      variables_list = variables_paths.flat_map { |c| c['variables'] }.uniq

      must_be_absolute_name = options.fetch(:must_be_absolute_name, false)
      retrieved_config_server_values = fetch_values_with_deployment(variables_list, variable_set, must_be_absolute_name)

      @deep_hash_replacer.replace_variables(raw_hash, variables_paths, retrieved_config_server_values)
    end

    # @param [Hash] link_properties_hash Link spec properties to be interpolated
    # @param [VariableSet] consumer_variable_set The variable set of the consumer deployment
    # @param [VariableSet] provider_variable_set The variable set of the provider deployment
    # @return [Hash] A Deep copy of the interpolated links spec
    def interpolate_cross_deployment_link(link_properties_hash, consumer_variable_set, provider_variable_set)
      return link_properties_hash if link_properties_hash.nil?
      raise "Unable to interpolate cross deployment link properties. Expected a 'Hash', got '#{link_properties_hash.class}'" unless link_properties_hash.is_a?(Hash)

      variables_paths = @deep_hash_replacer.variables_path(link_properties_hash)
      variables_list = variables_paths.flat_map { |c| c['variables'] }.uniq

      retrieved_config_server_values = resolve_cross_deployments_variables(variables_list, consumer_variable_set, provider_variable_set)

      @deep_hash_replacer.replace_variables(link_properties_hash, variables_paths, retrieved_config_server_values)
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
        if ConfigServerHelper.is_full_variable?(provided_prop)
          extracted_name = ConfigServerHelper.add_prefix_if_not_absolute(
            ConfigServerHelper.extract_variable_name(provided_prop),
            @director_name,
            deployment_name
          )
          extracted_name = get_name_root(extracted_name)

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

    def fetch_values_with_deployment(variables, variable_set, must_be_absolute_name)
      ConfigServerHelper.validate_absolute_names(variables) if must_be_absolute_name

      errors = []
      config_values = {}

      deployment_name = variable_set.deployment.name

      variables.each do |variable|
        name = ConfigServerHelper.add_prefix_if_not_absolute(
          ConfigServerHelper.extract_variable_name(variable),
          @director_name,
          deployment_name
        )

        begin
          name_root = get_name_root(name)

          saved_variable_mapping = variable_set.find_variable_by_name(name_root)

          if saved_variable_mapping.nil?
            raise Bosh::Director::ConfigServerInconsistentVariableState, "Expected variable '#{name_root}' to be already versioned in deployment '#{deployment_name}'" unless variable_set.writable

            variable_id, variable_value = get_variable_id_and_value_by_name(name)

            begin
              save_variable(name_root, variable_set, variable_id)
              config_values[variable] = variable_value
            rescue Sequel::UniqueConstraintViolation
              saved_variable_mapping = variable_set.find_variable_by_name(name_root)
              config_values[variable] = get_variable_value_by_id(saved_variable_mapping.variable_name, saved_variable_mapping.variable_id)
            end

          else
            config_values[variable] = get_variable_value_by_id(name, saved_variable_mapping.variable_id)
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
          ConfigServerHelper.extract_variable_name(variable),
          @director_name,
          provider_deployment_name
        )

        variable_composed_name = get_name_root(raw_variable_name)
        consumer_variable_model = consumer_variable_set.find_provided_variable_by_name(variable_composed_name, provider_deployment_name)

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
              consumer_variable_set.add_variable(variable_name: variable_name, variable_id: variable_id, is_local: false, provider_deployment: provider_deployment_name)
            rescue Sequel::UniqueConstraintViolation
              @logger.debug("Variable '#{variable_name}' was already added to consumer variable set '#{consumer_variable_set.id}'")
            end

            variable_id_to_fetch = provider_variable_model.variable_id
          end

          config_values[variable] = get_variable_value_by_id(raw_variable_name, variable_id_to_fetch)
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

    def fetch_values_with_latest(variables)
      ConfigServerHelper.validate_absolute_names(variables)

      errors = []
      config_values = {}

      variables.each do |variable|
        name = ConfigServerHelper.extract_variable_name(variable)

        begin
          variable_id, variable_value = get_variable_id_and_value_by_name(name)
          config_values[variable] = variable_value
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

    def get_variable_value_by_id(name, id)
      name_root = get_name_root(name)
      response = @config_server_http_client.get_by_id(id)

      fetched_variable = nil
      if response.kind_of? Net::HTTPOK
        begin
          fetched_variable = JSON.parse(response.body)
        rescue JSON::ParserError
          raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' with id '#{id}' from config server: Invalid JSON response"
        end
      elsif response.kind_of? Net::HTTPNotFound
        raise Bosh::Director::ConfigServerMissingName, "Failed to find variable '#{name_root}' with id '#{id}' from config server: HTTP code '404'"
      else
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' with id '#{id}' from config server: HTTP code '#{response.code}'"
      end

      raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected response to be a hash, got '#{fetched_variable.class}'" unless fetched_variable.is_a?(Hash)
      raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected response to have key 'id'" unless fetched_variable.has_key?('id')
      raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected response to have key 'value'" unless fetched_variable.has_key?('value')

      extract_variable_value(name, fetched_variable['value'])
    end

    def extract_variable_value(name, raw_value)
      name_tokens = name.split('.')
      name_root = name_tokens.shift

      name_tokens.each_with_index do |token, index|
        parent = index > 0 ? ([name_root] + name_tokens[0..(index - 1)]).join('.') : name_root
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected parent '#{parent}' to be a hash" unless raw_value.is_a?(Hash)
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected parent '#{parent}' hash to have key '#{token}'" unless raw_value.has_key?(token)

        raw_value = raw_value[token]
      end

      raw_value
    end

    def get_variable_id_and_value_by_name(name)
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

        fetched_variable = response_data[0]
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data[0] to have key 'id'" unless fetched_variable.has_key?('id')
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data[0] to have key 'value'" unless fetched_variable.has_key?('value')

        return fetched_variable['id'], extract_variable_value(name, fetched_variable['value'])
      elsif response.kind_of? Net::HTTPNotFound
        raise Bosh::Director::ConfigServerMissingName, "Failed to find variable '#{name_root}' from config server: HTTP code '404'"
      else
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: HTTP code '#{response.code}'"
      end
    end

    def name_exists?(name)
      get_variable_id_and_value_by_name(name)
      true
    rescue Bosh::Director::ConfigServerMissingName
      false
    end

    def save_variable(name_root, variable_set, variable_id)
      variable_set.add_variable(variable_name: name_root, variable_id: variable_id)
    end

    def generate_value(name, type, variable_set, options)
      parameters = options.nil? ? {} : options

      request_body = {
        'name' => name,
        'type' => type,
        'parameters' => parameters
      }

      unless variable_set.writable
        raise Bosh::Director::ConfigServerGenerationError, "Variable '#{get_name_root(name)}' cannot be generated. Variable generation allowed only during deploy action"
      end

      response = @config_server_http_client.post(request_body)
      unless response.kind_of? Net::HTTPSuccess
        @logger.error("Config server error while generating value for '#{name}': #{response.code}  #{response.message}. Request body sent: #{request_body}")
        raise Bosh::Director::ConfigServerGenerationError, "Config Server failed to generate value for '#{name}' with type '#{type}'. Error: '#{response.message}'"
      end

      generated_variable = nil
      begin
        generated_variable = JSON.parse(response.body)
      rescue JSON::ParserError
        raise Bosh::Director::ConfigServerGenerationError, "Config Server returned a NON-JSON body while generating value for '#{get_name_root(name)}' with type '#{type}'"
      end

      raise Bosh::Director::ConfigServerGenerationError, "Failed to version generated variable '#{name}'. Expected Config Server response to have key 'id'" unless generated_variable.has_key?('id')

      begin
        save_variable(get_name_root(name), variable_set, generated_variable['id'])
      rescue Sequel::UniqueConstraintViolation
        @logger.debug("variable '#{get_name_root(name)}' was already added to set '#{variable_set.id}'")
      end

      generated_variable
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
    def interpolate(src, options={})
      Bosh::Common::DeepCopy.copy(src)
    end

    def interpolate_with_versioning(src, variable_set, options={})
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
