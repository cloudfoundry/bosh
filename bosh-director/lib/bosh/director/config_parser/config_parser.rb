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

      config_server_hash = Bosh::Director::Config.config_server

      http = self.setup_http(config_server_hash)
      auth_provider = Bosh::Director::UAAAuthProvider.new(config_server_hash['uaa'], Bosh::Director::Config.logger)

      keys.each do |k|
        config_server_uri = URI.join(config_server_hash['url'], 'v1/', 'data/', k)

        begin
          response = http.get(config_server_uri.path, {'Authorization' => auth_provider.auth_header})
        rescue OpenSSL::SSL::SSLError
          raise 'SSL certificate verification failed'
        end

        if response.kind_of? Net::HTTPSuccess
          config_values[k] = JSON.parse(response.body)['value']
        else
          invalid_keys << k
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

    def self.setup_http(config_server_hash)
      config_server_uri = URI(config_server_hash['url'])
      http = Net::HTTP.new(config_server_uri.hostname, config_server_uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      ca_cert_path = config_server_hash['ca_cert_path']
      if File.exist?(ca_cert_path) && !File.read(ca_cert_path).strip.empty?
        http.ca_file = ca_cert_path
      else
        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths
        http.cert_store = cert_store
      end
      http
    end
  end
end