require 'net/http'

module Bosh::Director::Jobs
  module Helpers
    class ConfigParser

      class << self
        # Search and Replace at a config placeholders in manifest
        def parse(manifest)
          new_manifest = Marshal.load(Marshal.dump(manifest))

          config_map = DeepHashReplacement.replacement_map(new_manifest)
          parsed_config = apply_replacements(new_manifest, config_map)

          parsed_config
        end

        private

        def apply_replacements(manifest, config_map)
          config_keys = config_map.map { |c| c["key"] }.uniq

          config_values, invalid_keys = fetch_config_values(config_keys)

          if invalid_keys.length > 0
            raise "Unable to find keys " + invalid_keys.to_s
          end

          update_manifest!(manifest, config_map, config_values)

          manifest
        end

        def fetch_config_values(keys)
          invalid_keys = []
          config_values = {}

          keys.each do |k|
            response = Net::HTTP.get_response(config_uri(k))
            if response.kind_of? Net::HTTPSuccess
              config_values[k] = JSON.parse(response.body)['value']
            else
              invalid_keys << k
            end
          end

          [config_values, invalid_keys]
        end

        def config_uri(key)
          config_server_url = Bosh::Director::Config.config_server_url
          URI('http://' + config_server_url + '/v1/config/' + key)
        end

        def update_manifest!(manifest, config_map, config_values)
          config_map.each do |config_loc|
            config_path = config_loc['path']
            ret = config_path[0..config_path.length-2].inject(manifest) do |obj, el|
              obj[el]
            end

            ret[config_path.last] = config_values[config_loc['key']]
          end
        end
      end

    end
  end
end
