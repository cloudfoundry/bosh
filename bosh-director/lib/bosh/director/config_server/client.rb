require 'bosh/director/config_server/config_server_helper'

module Bosh::Director::ConfigServer
  class EnabledClient
    include ConfigServerHelper

    def initialize(http_client, logger)
      @config_server_http_client = http_client
      @deep_hash_replacer = DeepHashReplacement.new
      @logger = logger
    end

    # @param [Hash] src Hash to be interpolated
    # @param [Array] subtrees_to_ignore Array of paths that should not be interpolated in src
    # @return [Hash] A Deep copy of the interpolated src Hash
    def interpolate(src, subtrees_to_ignore = [])
      result = Bosh::Common::DeepCopy.copy(src)

      config_map = @deep_hash_replacer.replacement_map(src, subtrees_to_ignore)

      config_keys = config_map.map { |c| c['key'] }.uniq

      config_values, invalid_keys = fetch_config_values(config_keys)
      if invalid_keys.length > 0
        raise Bosh::Director::ConfigServerMissingKeys, "Failed to find keys in the config server: #{invalid_keys.join(", ")}"
      end

      replace_config_values!(config_map, config_values, result)
      result
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

      interpolate(deployment_manifest, ignored_subtrees)
    end

    # @param [Hash] runtime_manifest Runtime Manifest Hash to be interpolated
    # @return [Hash] A Deep copy of the interpolated manifest Hash
    def interpolate_runtime_manifest(runtime_manifest)
      ignored_subtrees = [
        ['addons', Integer, 'properties'],
        ['addons', Integer, 'jobs', Integer, 'properties'],
        ['addons', Integer, 'jobs', Integer, 'consumes', String, 'properties'],
      ]

      interpolate(runtime_manifest, ignored_subtrees)
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
      response = @config_server_http_client.get(key)

      if response.kind_of? Net::HTTPOK
        JSON.parse(response.body)['value']
      elsif response.kind_of? Net::HTTPNotFound
        raise Bosh::Director::ConfigServerMissingKeys, "Failed to find key '#{key}' in the config server"
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

    def fetch_config_values(keys)
      invalid_keys = []
      config_values = {}

      keys.each do |k|
        begin
          config_values[k] = get_value_for_key(k)
        rescue Bosh::Director::ConfigServerMissingKeys
          invalid_keys << k
        end
      end

      [config_values, invalid_keys]
    end

    def replace_config_values!(config_map, config_values, obj_to_be_resolved)
      config_map.each do |config_loc|
        config_path = config_loc['path']
        ret = obj_to_be_resolved

        if config_path.length > 1
          ret = config_path[0..config_path.length-2].inject(obj_to_be_resolved) do |obj, el|
            obj[el]
          end
        end
        ret[config_path.last] = config_values[config_loc['key']]
      end
    end

    def generate_password(key)
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
    def interpolate(src, subtrees_to_ignore = [])
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