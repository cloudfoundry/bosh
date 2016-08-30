module Bosh::Director::ConfigServer
  class Client

    def initialize(http_client, logger)
      @config_server_http_client = http_client
      @logger = logger
    end

    # @param [Hash] src Hash to be interpolated
    # @param [Array] subtrees_to_ignore Array of paths that should not be interpolated in src
    # @return [Hash] A Deep copy of the interpolated src Hash
    def interpolate(src, subtrees_to_ignore = [])
      result = Bosh::Common::DeepCopy.copy(src)
      config_map = Bosh::Director::ConfigServer::DeepHashReplacement.replacement_map(src, subtrees_to_ignore)

      config_keys = config_map.map { |c| c["key"] }.uniq

      config_values, invalid_keys = fetch_config_values(config_keys)
      if invalid_keys.length > 0
        raise Bosh::Director::ConfigServerMissingKeys, "Failed to find keys in the config server: #{invalid_keys.join(", ")}"
      end

      replace_config_values!(config_map, config_values, result)
      result
    end

    # @param [String] key The key for which a value will be generated
    # @param [String] type The type of value generated (example: password, certificate, ....)
    def populate_value_for(key, type)
      if !key.nil? && key.to_s.match(/^\(\(.*\)\)$/)
        stripped_key = key.gsub(/(^\(\(|\)\)$)/, '')

        case type
          when 'password'
            begin
              get_value_for_key(stripped_key)
            rescue Bosh::Director::ConfigServerMissingKeys
              generate_password(stripped_key)
            end
        end
      end
    end

    def interpolate_deployment_manifest(deployment_manifest)
      index_type = Integer
      any_string = String

      ignored_subtrees = []
      ignored_subtrees << ['properties']
      ignored_subtrees << ['instance_groups', index_type, 'properties']
      ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'properties']
      ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'consumes', any_string, 'properties']
      ignored_subtrees << ['jobs', index_type, 'properties']
      ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'properties']
      ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'consumes', any_string, 'properties']

      ignored_subtrees << ['instance_groups', index_type, 'env']
      ignored_subtrees << ['jobs', index_type, 'env']
      ignored_subtrees << ['resource_pools', index_type, 'env']

      interpolate(deployment_manifest, ignored_subtrees)
    end


    def interpolate_runtime_manifest(runtime_manifest)
      index_type = Integer
      any_string = String

      ignored_subtrees = []
      ignored_subtrees << ['addons', index_type, 'properties']
      ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'properties']
      ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'consumes', any_string, 'properties']

      interpolate(runtime_manifest, ignored_subtrees)
    end

    private

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

    def generate_password(stripped_key)
      request_body = {
        'type' => 'password'
      }
      response = @config_server_http_client.post(stripped_key, request_body)

      unless response.kind_of? Net::HTTPSuccess
        raise Bosh::Director::ConfigServerPasswordGenerationError, 'Config Server failed to generate password'
      end
    end

    def get_value_for_key(key)
      response = @config_server_http_client.get(key)

      if response.kind_of? Net::HTTPSuccess
        JSON.parse(response.body)['value']
      else
        raise Bosh::Director::ConfigServerMissingKeys, "Failed to find key '#{key}' in the config server"
      end
    end
  end

  class DummyClient
    def interpolate(src, subtrees_to_ignore = [])
      Bosh::Common::DeepCopy.copy(src)
    end

    def interpolate_deployment_manifest(manifest)
      Bosh::Common::DeepCopy.copy(manifest)
    end

    def interpolate_runtime_manifest(manifest)
      Bosh::Common::DeepCopy.copy(manifest)
    end

    def populate_value_for(key, type)
    end
  end
end