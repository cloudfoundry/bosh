require 'net/http'

module Bosh::Director::ConfigServer
  class ConfigServerEnabledHTTPClient
    def initialize(http_client)
      @http = http_client

      config_server_hash = Bosh::Director::Config.config_server
      @config_server_uri = URI(config_server_hash['url'])
    end

    def get_by_id(id)
      uri = URI.join(@config_server_uri, "v1/data/#{id}")
      @http.get(uri.request_uri)
    end

    def get(name)
      uri = build_base_uri
      uri.query = URI.encode_www_form([["name", name], ["current", "true"]])
      @http.get(uri.request_uri)
    end

    def post(body)
      uri = build_base_uri
      @http.post(uri.path, JSON.dump(body), {'Content-Type' => 'application/json'})
    end

    private

    def build_base_uri
      URI.join(@config_server_uri, 'v1/data')
    end
  end

  class ConfigServerDisabledHTTPClient
    def get_by_id(id)
      raise Bosh::Director::ConfigServerDisabledError, "Failed to fetch variable with id '#{id}' from config server: Director is not configured with a config server"
    end

    def get(name)
      raise Bosh::Director::ConfigServerDisabledError, "Failed to fetch variable '#{name}' from config server: Director is not configured with a config server"
    end

    def post(body)
      raise Bosh::Director::ConfigServerDisabledError, "Failed to generate variable '#{body['name']}' from config server: Director is not configured with a config server"
    end
  end
end
