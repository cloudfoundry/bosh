require 'bosh/director/config_server/config_server_helper'

module Bosh::Director::ConfigServer
  class ConfigServerClient
    GENERATION_MODE_OVERWRITE = 'overwrite'.freeze
    GENERATION_MODE_CONVERGE = 'converge'.freeze
    GENERATION_MODE_NO_OVERWRITE = 'no-overwrite'.freeze

    ON_DEPLOY_UPDATE_STRATEGY = 'on-deploy'.freeze
    ON_STEMCELL_CHANGE_UPDATE_STRATEGY = 'on-stemcell-change'.freeze

    def initialize(http_client, director_name, logger)
      @config_server_http_client = http_client
      @director_name = director_name
      @deep_hash_replacer = DeepHashReplacement.new
      @deployment_lookup = Bosh::Director::Api::DeploymentLookup.new
      @logger = logger
      @cache_by_id = {}
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
      raise 'Variable Set cannot be nil.' if variable_set.nil?

      subtrees_to_ignore = options.fetch(:subtrees_to_ignore, [])

      variables_paths = @deep_hash_replacer.variables_path(raw_hash, subtrees_to_ignore)
      variables_list = variables_paths.flat_map { |c| c['variables'] }.uniq

      must_be_absolute_name = options.fetch(:must_be_absolute_name, false)
      retrieved_config_server_values = fetch_values_with_deployment(variables_list, variable_set, must_be_absolute_name)

      @deep_hash_replacer.replace_variables(raw_hash, variables_paths, retrieved_config_server_values)
    end

    def interpolated_versioned_variables_changed?(previous_raw_hash, next_raw_hash, previous_variable_set, target_variable_set)
      begin
        old_vars = interpolate_with_versioning(previous_raw_hash, previous_variable_set)
      rescue Bosh::Director::ConfigServerFetchError => e
        @logger.debug("Failed to fetch all variables while comparing with old variable set: #{e.message}")
        return true
      end
      target_vars = interpolate_with_versioning(next_raw_hash, target_variable_set)
      target_vars != old_vars
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

    # @param [DeploymentPlan::Variables] variables Object representing variables passed by the user
    # @param [String] deployment_name
    def generate_values(variables, deployment_name, converge_variables = false, use_link_dns_names = false, stemcell_change = false)
      deployment_model = @deployment_lookup.by_name(deployment_name)

      variables.spec.map do |variable|
        ConfigServerHelper.validate_variable_name(variable['name'])
        constructed_name = ConfigServerHelper.add_prefix_if_not_absolute(variable['name'], @director_name, deployment_name)

        strategy = variable.dig('update', 'strategy') || ON_DEPLOY_UPDATE_STRATEGY
        use_latest_version =
          strategy == ON_DEPLOY_UPDATE_STRATEGY ||
          stemcell_change && strategy == ON_STEMCELL_CHANGE_UPDATE_STRATEGY ||
          deployment_model.previous_variable_set&.find_variable_by_name(constructed_name).nil?

        if use_latest_version
          if variable['type'] == 'certificate'
            has_ca = variable['options'] && variable['options']['ca']
            generate_ca(variable, deployment_name) if has_ca
            variable = generate_links(variable, deployment_model, use_link_dns_names)
          end

          generation_mode = variable['update_mode']
          generation_mode ||= converge_variables ? GENERATION_MODE_CONVERGE : GENERATION_MODE_NO_OVERWRITE

          variable_id = generate_latest_version_id(
            constructed_name,
            variable['type'],
            deployment_name,
            deployment_model.current_variable_set,
            variable['options'],
            generation_mode,
          )
        else
          previous_variable_version = deployment_model.previous_variable_set.find_variable_by_name(constructed_name)
          variable_id = previous_variable_version[:variable_id]
        end

        begin
          save_variable(get_name_root(constructed_name), deployment_model.current_variable_set, variable_id)
        rescue Sequel::UniqueConstraintViolation
          @logger.debug("variable '#{get_name_root(constructed_name)}' was already added to set '#{deployment_model.current_variable_set.id}'")
        end

        add_event(
          action: 'create',
          deployment_name: deployment_name,
          object_name: constructed_name,
          context: { 'update_strategy' => strategy, 'latest_version' => use_latest_version, 'name' => constructed_name, 'id' => variable_id },
        )

        variable
      end
    end

    def get_variable_value_by_id(name, id)
      name_root = get_name_root(name)
      fetched_variable = get_by_id(id, name_root)

      extract_variable_value(name, fetched_variable['value'])
    end

    def force_regenerate_value(name, type, options)
      generate_value(name, type, options, GENERATION_MODE_OVERWRITE)
    end

    private

    def generate_ca(variable, deployment_name)
      variable['options']['ca'] = ConfigServerHelper.add_prefix_if_not_absolute(
        variable['options']['ca'],
        @director_name,
        deployment_name,
      )
    end

    def generate_links(variable, deployment_model, use_link_dns_names)
      links = find_variable_link(deployment_model, variable['name'])

      return variable if links.empty?

      start_options = variable['options'] || {}
      variable['options'] = links.reduce(start_options) do |options, (type, link)|
        link_url = generate_dns_address_from_link(link, use_link_dns_names)

        if type == 'alternative_name'
          options['alternative_names'] ||= []
          options['alternative_names'] << link_url
        elsif type == 'common_name'
          options[type] ||= link_url
        end

        options
      end

      variable
    end

    def generate_wildcard(link_url)
      exploded = link_url.split('.', 2)
      exploded[0] = '*'
      exploded.join('.')
    end

    def find_variable_link(deployment_model, variable_name)
      links_manager = Bosh::Director::Links::LinksManager.new(deployment_model.links_serial_id)

      consumer = links_manager.find_consumer(
        deployment_model: deployment_model,
        instance_group_name: '',
        name: variable_name,
        type: 'variable',
      )

      return {} if consumer.nil?

      result = {}
      consumer.intents.each do |consumer_intent|
        result[consumer_intent.original_name] = consumer_intent.links.first
      end
      result
    end

    def generate_dns_address_from_link(link, use_link_dns_names)
      link_content = JSON.parse(link.link_content)

      return link_content['address'] if link.link_provider_intent&.link_provider&.type == 'manual'

      use_short_dns_addresses = link_content.fetch('use_short_dns_addresses', false)
      group_type = Bosh::Director::Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP
      group_name = link_content['instance_group']
      if use_link_dns_names
        use_short_dns_addresses = true
        group_type = Bosh::Director::Models::LocalDnsEncodedGroup::Types::LINK
        group_name = link.group_name
      end

      dns_encoder = Bosh::Director::LocalDnsEncoderManager.create_dns_encoder(use_short_dns_addresses, use_link_dns_names)
      query_criteria = {
        group_type: group_type,
        group_name: group_name,
        deployment_name: link_content['deployment_name'],
        default_network: link_content['default_network'],
        root_domain: link_content['domain'],
      }
      url = dns_encoder.encode_query(query_criteria)
      url = generate_wildcard(url) if link_wants_wildcard(link)
      url
    end

    def link_wants_wildcard(link)
      metadata = JSON.parse(link.link_consumer_intent.metadata || '{}')
      metadata['wildcard'] || false
    end

    def fetch_values_with_deployment(variables, variable_set, must_be_absolute_name)
      ConfigServerHelper.validate_absolute_names(variables) if must_be_absolute_name

      errors = []
      config_values = {}

      deployment_name = variable_set.deployment.name

      variables.each do |variable|
        name = ConfigServerHelper.add_prefix_if_not_absolute(
          ConfigServerHelper.extract_variable_name(variable),
          @director_name,
          deployment_name,
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

      unless errors.empty?
        message = errors.map { |error| "- #{error.message}" }.join("\n")
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
          provider_deployment_name,
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

      unless errors.empty?
        message = errors.map { |error| "- #{error.message}" }.join("\n")
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

      unless errors.empty?
        message = errors.map { |error| "- #{error.message}" }.join("\n")
        raise Bosh::Director::ConfigServerFetchError, message
      end

      config_values
    end

    def extract_variable_value(name, raw_value)
      name_tokens = name.split('.')
      name_root = name_tokens.shift

      name_tokens.each_with_index do |token, index|
        parent = index > 0 ? ([name_root] + name_tokens[0..(index - 1)]).join('.') : name_root
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected parent '#{parent}' to be a hash" unless raw_value.is_a?(Hash)
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected parent '#{parent}' hash to have key '#{token}'" unless raw_value.key?(token)

        raw_value = raw_value[token]
      end

      raw_value
    end

    def get_variable_id_and_value_by_name(name)
      name_root = get_name_root(name)
      response = @config_server_http_client.get(name_root)

      begin
        response_body = JSON.parse(response.body)
      rescue JSON::ParserError
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Invalid JSON response"
      end

      if response.is_a? Net::HTTPOK
        response_data = response_body['data']

        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data to be an array" unless response_data.is_a?(Array)
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data to be non empty array" if response_data.empty?

        fetched_variable = response_data[0]
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data[0] to have key 'id'" unless fetched_variable.key?('id')
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected data[0] to have key 'value'" unless fetched_variable.key?('value')

        [fetched_variable['id'], extract_variable_value(name, fetched_variable['value'])]
      elsif response.is_a? Net::HTTPNotFound
        raise Bosh::Director::ConfigServerMissingName, "Failed to find variable '#{name_root}' from config server: HTTP Code '404', Error: '#{response_body['error']}'"
      else
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: HTTP Code '#{response.code}', Error: '#{response_body['error']}'"
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

    def generate_value(name, type, options, mode)
      parameters = options.nil? ? {} : options

      request_body = {
        'name' => name,
        'type' => type,
        'parameters' => parameters,
        'mode' => mode,
      }

      response = @config_server_http_client.post(request_body)

      begin
        parsed_response_body = JSON.parse(response.body)
      rescue JSON::ParserError
        raise Bosh::Director::ConfigServerGenerationError, "Config Server returned a NON-JSON body while generating value for '#{get_name_root(name)}' with type '#{type}'"
      end

      unless response.is_a? Net::HTTPSuccess
        @logger.error("Config server error while generating value for '#{name}': #{response.code}  #{parsed_response_body['error']}. Request body sent: #{request_body}")
        raise Bosh::Director::ConfigServerGenerationError, "Config Server failed to generate value for '#{name}' with type '#{type}'. HTTP Code '#{response.code}', Error: '#{parsed_response_body['error']}'"
      end

      parsed_response_body
    end

    def get_name_root(variable_name)
      name_tokens = variable_name.split('.')
      name_tokens[0]
    end

    def add_event(options)
      Bosh::Director::Config.current_job.event_manager.create_event(
        user: Bosh::Director::Config.current_job.username,
        object_type: 'variable',
        task: Bosh::Director::Config.current_job.task_id,
        action: options.fetch(:action),
        object_name: options.fetch(:object_name),
        deployment: options.fetch(:deployment_name),
        context: options.fetch(:context, {}),
        error: options.fetch(:error, nil),
      )
    end

    def generate_latest_version_id(variable_name, variable_type, deployment_name, variable_set, options, generation_mode)
      unless variable_set.writable
        raise Bosh::Director::ConfigServerGenerationError,
              "Variable '#{get_name_root(variable_name)}' cannot be generated. Variable generation allowed only during deploy action"
      end

      generated_variable = generate_value(variable_name, variable_type, options, generation_mode)

      raise Bosh::Director::ConfigServerGenerationError, "Failed to version generated variable '#{variable_name}'. Expected Config Server response to have key 'id'" unless generated_variable.key?('id')

      generated_variable['id']
    rescue Exception => e
      add_event(
        action: 'create',
        deployment_name: deployment_name,
        object_name: variable_name,
        error: e,
      )
      raise e
    end

    def get_by_id(id, name_root)
      return @cache_by_id[id] if @cache_by_id.has_key?(id)

      response = @config_server_http_client.get_by_id(id)

      begin
        parsed_response = JSON.parse(response.body)
      rescue JSON::ParserError
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' with id '#{id}' from config server: Invalid JSON response"
      end

      if response.kind_of? Net::HTTPNotFound
        raise Bosh::Director::ConfigServerMissingName, "Failed to find variable '#{name_root}' with id '#{id}' from config server: HTTP Code '404', Error: '#{parsed_response['error']}'"
      elsif !response.kind_of? Net::HTTPOK
        raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' with id '#{id}' from config server: HTTP Code '#{response.code}', Error: '#{parsed_response['error']}'"
      end

      raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected response to be a hash, got '#{parsed_response.class}'" unless parsed_response.is_a?(Hash)
      raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected response to have key 'id'" unless parsed_response.has_key?('id')
      raise Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '#{name_root}' from config server: Expected response to have key 'value'" unless parsed_response.has_key?('value')

      @cache_by_id[parsed_response['id']] = parsed_response
      parsed_response
    end
  end
end
