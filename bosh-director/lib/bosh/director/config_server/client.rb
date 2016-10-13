require 'bosh/director/config_server/config_server_helper'

module Bosh::Director::ConfigServer
  class EnabledClient
    include ConfigServerHelper

    def initialize(http_client, director_name, deployment_name, logger)
      @config_server_http_client = http_client
      @director_name = director_name
      @deployment_name = deployment_name
      @deep_hash_replacer = DeepHashReplacement.new
      @logger = logger
    end

    # @param [Hash] src Hash to be interpolated
    # @param [Array] subtrees_to_ignore Array of paths that should not be interpolated in src
    # @param [Boolean] must_be_absolute_key Flag to check if all the placeholders start with '/'
    # @return [Hash] A Deep copy of the interpolated src Hash
    def interpolate(src, subtrees_to_ignore = [], must_be_absolute_key = false)
      placeholders_paths = @deep_hash_replacer.placeholders_paths(src, subtrees_to_ignore)
      placeholders_list = placeholders_paths.map { |c| c['placeholder'] }.uniq

      retrieved_config_server_values, missing_keys = fetch_keys_values(placeholders_list, must_be_absolute_key)
      if missing_keys.length > 0
        raise Bosh::Director::ConfigServerMissingKeys, "Failed to load placeholder keys from the config server: #{missing_keys.join(', ')}"
      end

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

      interpolate(deployment_manifest, ignored_subtrees, false)
    end

    # @param [Hash] runtime_manifest Runtime Manifest Hash to be interpolated
    # @return [Hash] A Deep copy of the interpolated manifest Hash
    def interpolate_runtime_manifest(runtime_manifest)
      ignored_subtrees = [
        ['addons', Integer, 'properties'],
        ['addons', Integer, 'jobs', Integer, 'properties'],
        ['addons', Integer, 'jobs', Integer, 'consumes', String, 'properties'],
      ]

      interpolate(runtime_manifest, ignored_subtrees, true)
    end

    # @param [Object] provided_prop property value
    # @param [Object] default_prop property value
    # @param [String] type of property
    # @param [Hash] options hash containing extra options when needed
    # @return [Object] either the provided_prop or the default_prop
    def prepare_and_get_property(provided_prop, default_prop, type, options = {})
      if provided_prop.nil?
        result = default_prop
      else
        if is_placeholder?(provided_prop)
          extracted_key = extract_placeholder_key(provided_prop)

          if key_exists?(extracted_key)
            result = provided_prop
          else
            if default_prop.nil?
              case type
                when 'password'
                  generate_password(extracted_key)
                when 'certificate'
                  generate_certificate(extracted_key, options)
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

    private

    def get_value_for_key(key)
      key = add_prefix_if_not_absolute(key, @director_name, @deployment_name)
      response = @config_server_http_client.get(key)

      if response.kind_of? Net::HTTPOK
        JSON.parse(response.body)['value']
      elsif response.kind_of? Net::HTTPNotFound
        raise Bosh::Director::ConfigServerMissingKeys, "Failed to load placeholder key '#{key}' from the config server"
      else
        raise Bosh::Director::ConfigServerUnknownError, "Unknown config server error: #{response.code}  #{response.message.dump}"
      end
    end

    def key_exists?(key)
      begin
        get_value_for_key(key)
        true
      rescue Bosh::Director::ConfigServerMissingKeys
        false
      end
    end

    def fetch_keys_values(placeholders, must_be_absolute_key)
      missing_keys = []
      config_values = {}

      if must_be_absolute_key
        non_absolute_keys = placeholders.inject([]) do |memo, placeholder|
          key = extract_placeholder_key(placeholder)
          memo << key unless key.start_with?('/')
          memo
        end
        raise Bosh::Director::ConfigServerIncorrectKeySyntax, 'Keys must be absolute path: ' + non_absolute_keys.join(',') unless non_absolute_keys.empty?
      end

      placeholders.each do |placeholder|
        key = extract_placeholder_key(placeholder)
        begin
          config_values[placeholder] = get_value_for_key(key)
        rescue Bosh::Director::ConfigServerMissingKeys
          missing_keys << key
        end
      end

      [config_values, missing_keys]
    end

    def generate_password(key)
      key = add_prefix_if_not_absolute(key, @director_name, @deployment_name)
      request_body = {
        'type' => 'password'
      }

      response = @config_server_http_client.post(key, request_body)

      unless response.kind_of? Net::HTTPSuccess
        @logger.error("Config server error on generating password: #{response.code}  #{response.message}. Request body sent: #{request_body}")
        raise Bosh::Director::ConfigServerPasswordGenerationError, 'Config Server failed to generate password'
      end
    end

    def generate_certificate(key, options)
      key = add_prefix_if_not_absolute(key, @director_name, @deployment_name)
      dns_record_names = options[:dns_record_names]
      request_body = {
        'type' => 'certificate',
        'parameters' => {
          'common_name' => dns_record_names.first,
          'alternative_names' => dns_record_names
        }
      }

      response = @config_server_http_client.post(key, request_body)

      unless response.kind_of? Net::HTTPSuccess
        @logger.error("Config server error on generating certificate: #{response.code}  #{response.message}. Request body sent: #{request_body}")
        raise Bosh::Director::ConfigServerCertificateGenerationError, 'Config Server failed to generate certificate'
      end
    end
  end

  class DisabledClient
    def interpolate(src, subtrees_to_ignore = [], must_be_absolute_key = false)
      Bosh::Common::DeepCopy.copy(src)
    end

    def interpolate_deployment_manifest(manifest)
      Bosh::Common::DeepCopy.copy(manifest)
    end

    def interpolate_runtime_manifest(manifest)
      Bosh::Common::DeepCopy.copy(manifest)
    end

    def prepare_and_get_property(manifest_provided_prop, default_prop, type, options = {})
      manifest_provided_prop.nil? ? default_prop : manifest_provided_prop
    end
  end
end