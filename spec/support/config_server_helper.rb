require 'net/http'
require 'json'

module Bosh::Spec
  class ConfigServerHelper
    def initialize(port)
      @port = port
    end

    def put_value(key, value)
      config_server_url = URI.join("http://127.0.0.1:#{@port}", 'v1/', 'data/', key)
      http = Net::HTTP.new(config_server_url.host, config_server_url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.ca_file = Bosh::Dev::Sandbox::ConfigServerService::ROOT_CERT

      response = http.send_request('PUT', config_server_url.request_uri, JSON.dump({value: value}))
      raise "Config server responded with an error.\n #{response.inspect}" unless response.kind_of? Net::HTTPSuccess
    end
  end
end
