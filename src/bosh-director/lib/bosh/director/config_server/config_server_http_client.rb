require 'net/http'

module Bosh::Director::ConfigServer
  class ConfigServerHTTPClient
    def initialize(http_client)
      @http = http_client

      config_server_hash = Bosh::Director::Config.config_server
      @config_server_uri = URI(config_server_hash['url'])
    end

    def get_by_id(id)
      uri = URI.join(@config_server_uri, URI.escape("v1/data/#{id}"))
      @http.get(uri.request_uri)
    end

    def get(name)
      uri = build_base_uri
      uri.query = URI.escape("name=#{name}&current=true")
      @http.get(uri.request_uri)
    end

    def post(body)
      uri = build_base_uri
      @http.post(uri.path, Yajl::Encoder.encode(body), {'Content-Type' => 'application/json'})
    end

    private

    def build_base_uri
      URI.join(@config_server_uri, URI.escape('v1/data'))
    end
  end
end