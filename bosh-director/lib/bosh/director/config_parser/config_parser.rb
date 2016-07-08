module Bosh::Director::ConfigServer

  class ConfigParser

    def initialize(obj)
      @obj = Bosh::Common::DeepCopy.copy(obj)
    end

    def parsed
      @config_map = Bosh::Director::ConfigServer::DeepHashReplacement.replacement_map(@obj)
      config_keys = @config_map.map { |c| c["key"] }.uniq

      @config_values, invalid_keys = fetch_config_values(config_keys)
      if invalid_keys.length > 0
        raise "Failed to find keys in the config server: " + invalid_keys.join(", ")
      end

      replace_config_values!
      @obj
    end

    private

    def fetch_config_values(keys)
      invalid_keys = []
      config_values = {}

      keys.each do |k|
        config_server_uri = URI.join(Bosh::Director::Config.config_server_url, 'v1/', 'data/', k)

        http = Net::HTTP.new(config_server_uri.hostname, config_server_uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file = Bosh::Director::Config.config_server_cert_path

        begin
          response = http.get(config_server_uri.path)
        rescue OpenSSL::SSL::SSLError
          raise "SSL certificate verification failed"
        end

        if response.kind_of? Net::HTTPSuccess
          config_values[k] = JSON.parse(response.body)['value']
        else
          invalid_keys << k
        end
      end

      [config_values, invalid_keys]
    end

    def replace_config_values!
      @config_map.each do |config_loc|
        config_path = config_loc['path']

        ret = config_path[0..config_path.length-2].inject(@obj) do |obj, el|
          obj[el]
        end
        ret[config_path.last] = @config_values[config_loc['key']]
      end
    end

  end
end