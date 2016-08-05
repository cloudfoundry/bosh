require 'net/http'
require 'json'

module Bosh::Spec
  class ConfigServerHelper
    def initialize(sandbox)
      @port = sandbox.port_provider.get_port(:config_server_port)
      @uaa_config_hash = {
          'client_id' => sandbox.director_config.config_server_uaa_client_id,
          'client_secret' => sandbox.director_config.config_server_uaa_client_secret,
          'url' => sandbox.director_config.config_server_uaa_url,
          'ca_cert_path' => sandbox.director_config.config_server_uaa_ca_cert_path
      }
    end

    def put_value(key, value)
      config_server_url = URI.join("http://127.0.0.1:#{@port}", 'v1/', 'data/', key)
      http = Net::HTTP.new(config_server_url.host, config_server_url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.ca_file = Bosh::Dev::Sandbox::ConfigServerService::ROOT_CERT

      auth_provider = Bosh::Director::UAAAuthProvider.new(@uaa_config_hash, logger)
      auth_header = auth_provider.auth_header
      response = http.send_request('PUT', config_server_url.request_uri, JSON.dump({value: value}), {'Authorization' => auth_header})

      raise "Config server responded with an error.\n #{response.inspect}" unless response.kind_of? Net::HTTPSuccess
    end

    def logger
      @logger ||= Bosh::Director::Config.logger
    end

  end
end
