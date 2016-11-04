require 'net/http'
require 'json'

module Bosh::Spec
  class ConfigServerHelper
    def initialize(sandbox, logger)
      @logger = logger
      @port = sandbox.port_provider.get_port(:config_server_port)
      @uaa_config_hash = {
          'client_id' => sandbox.director_config.config_server_uaa_client_id,
          'client_secret' => sandbox.director_config.config_server_uaa_client_secret,
          'url' => sandbox.director_config.config_server_uaa_url,
          'ca_cert_path' => sandbox.director_config.config_server_uaa_ca_cert_path
      }
    end

    def put_value(name, value)
      config_server_url = build_uri(name)
      response = send_request('PUT', config_server_url, JSON.dump({value: value}))
      raise "Config server responded with an error.\n #{response.inspect}" unless response.kind_of? Net::HTTPSuccess
    end

    def get_value(name)
      config_server_url = build_uri(name)
      response = send_request('GET', config_server_url, nil)
      raise "Config server responded with an error.\n #{response.inspect}" unless response.kind_of? Net::HTTPSuccess
      JSON.parse(response.body)['value']
    end

    def send_request(verb, url, body)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.ca_file = Bosh::Dev::Sandbox::ConfigServerService::ROOT_CERT

      auth_provider = Bosh::Director::UAAAuthProvider.new(@uaa_config_hash, @logger)
      auth_header = auth_provider.auth_header
      http.send_request(verb, url.request_uri, body, {'Authorization' => auth_header, 'Content-Type' => 'application/json'})
    end

    def build_uri(name)
      URI.join("http://127.0.0.1:#{@port}", URI.escape('v1/data/' + name))
    end
  end
end
