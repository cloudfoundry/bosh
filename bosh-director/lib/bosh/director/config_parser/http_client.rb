require 'net/http'

module Bosh::Director::ConfigServer
  class HTTPClient
    def initialize
      config_server_hash = Bosh::Director::Config.config_server

      @auth_provider = Bosh::Director::UAAAuthProvider.new(config_server_hash['uaa'], Bosh::Director::Config.logger)

      @config_server_uri = URI(config_server_hash['url'])

      @http = Net::HTTP.new(@config_server_uri.hostname, @config_server_uri.port)
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      ca_cert_path = config_server_hash['ca_cert_path']
      set_cert_store(ca_cert_path)
    end

    def get(key)
      config_server_uri = URI.join(@config_server_uri, 'v1/', 'data/', key)
      begin
        @http.get(config_server_uri.path, {'Authorization' => @auth_provider.auth_header})
      rescue OpenSSL::SSL::SSLError
        raise Bosh::Director::ConfigServerSSLError, 'Config Server SSL error'
      end
    end

    def post(key, body)
      config_server_uri = URI.join(@config_server_uri, 'v1/', 'data/', key)

      begin
        @http.post(config_server_uri.path, Yajl::Encoder.encode(body), {'Authorization' => @auth_provider.auth_header})
      rescue OpenSSL::SSL::SSLError
        raise Bosh::Director::ConfigServerSSLError, 'Config Server SSL error'
      end
    end

    def get_value_for_key(key)
      response = get(key)

      if response.kind_of? Net::HTTPSuccess
        JSON.parse(response.body)['value']
      else
        raise Bosh::Director::ConfigServerMissingKeys, "Failed to find key '#{key}' in the config server"
      end
    end

    def generate_password(password_placeholder)
      request_body = {
        'type' => 'password'
      }
      response = post(password_placeholder, request_body)

      unless response.kind_of? Net::HTTPSuccess
        raise Bosh::Director::ConfigServerPasswordGenerationError, 'Config Server failed to generate password'
      end
    end

    private

    def set_cert_store(ca_cert_path)
      if ca_cert_path && File.exist?(ca_cert_path) && !File.read(ca_cert_path).strip.empty?
        @http.ca_file = ca_cert_path
      else
        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths
        @http.cert_store = cert_store
      end
    end
  end
end