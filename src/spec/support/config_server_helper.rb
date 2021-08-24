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

    def post(name, type)
      json_body = { "name": name, "type": type}
      if type == "root-certificate"
        json_body = {"name": name,"type": "certificate","parameters":{"is_ca": true, "common_name": "#{name}-cn", "alternative_names":["#{name}-an"]}}
      end
      response = send_request('POST', build_uri, JSON.dump(json_body))
      raise "Config server responded with an error.\n #{response.inspect}" unless response.is_a? Net::HTTPSuccess

      JSON.parse(response.body)
    end

    def put_value(name, value)
      response = send_request('PUT', build_uri, JSON.dump({name: name, value: value}))
      raise "Config server responded with an error.\n #{response.inspect}" unless response.is_a? Net::HTTPSuccess
    end

    def get_value(name)
      config_server_url = build_uri
      config_server_url.query = URI.encode_www_form(['name', name])

      response = send_request('GET', config_server_url, nil)
      raise "Config server responded with an error.\n #{response.inspect}" unless response.is_a? Net::HTTPSuccess
      JSON.parse(response.body)['data'][0]['value']
    end

    def delete_variable(name)
      config_server_url = build_uri
      config_server_url.query = URI.encode_www_form(['name', name])

      response = send_request('DELETE', config_server_url, nil)
      raise "Config server responded with an error.\n #{response.inspect}" unless response.is_a? Net::HTTPSuccess
    end

    def send_request(verb, url, body)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.ca_file = Bosh::Dev::Sandbox::ConfigServerService::ROOT_CERT
      http.send_request(verb, url.request_uri, body, {'Authorization' => auth_header, 'Content-Type' => 'application/json'})
    end

    def auth_header
      auth_provider = Bosh::Director::ConfigServer::UAAAuthProvider.new(@uaa_config_hash, logger)
      ex = nil

      20.times do
        begin
          return auth_provider.get_token.auth_header
        rescue => ex
          sleep(5)
        end
      end

      raise "Could not obtain UAA token: #{ex.inspect}"
    end

    def logger
      @logger ||= Bosh::Director::Config.logger
    end

    def build_uri
      URI("http://127.0.0.1:#{@port}/v1/data")
    end
  end
end
