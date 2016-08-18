module Bosh::Director::ConfigServer

  class ConfigParser

    def self.parse(obj_to_be_parsed, subtrees_to_ignore = [])
      result = Bosh::Common::DeepCopy.copy(obj_to_be_parsed)
      config_map = Bosh::Director::ConfigServer::DeepHashReplacement.replacement_map(obj_to_be_parsed, subtrees_to_ignore)

      config_keys = config_map.map { |c| c["key"] }.uniq

      config_values, invalid_keys = fetch_config_values(config_keys)
      if invalid_keys.length > 0
        raise Bosh::Director::ConfigServerMissingKeys, "Failed to find keys in the config server: #{invalid_keys.join(", ")}"
      end

      replace_config_values!(config_map, config_values, result)
      result
    end

    private

    def self.fetch_config_values(keys)
      invalid_keys = []
      config_values = {}

      http = HTTPClient.new

      keys.each do |k|
        config_value = http.get(k)

        if config_value.nil?
          invalid_keys << k
        else
          config_values[k] = config_value['value']
        end
      end

      [config_values, invalid_keys]
    end

    def self.replace_config_values!(config_map, config_values, obj_to_be_resolved)
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
  end
end