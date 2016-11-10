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

    def get(name)
      uri = build_uri(name)
      begin
        @http.get(uri.path, {'Authorization' => @auth_provider.auth_header})
      rescue OpenSSL::SSL::SSLError
        raise Bosh::Director::ConfigServerSSLError, 'Config Server SSL error'
      end
    end

    def post(name, body)
      uri = build_uri(name)
      begin
        @http.post(uri.path, Yajl::Encoder.encode(body), {'Authorization' => @auth_provider.auth_header, 'Content-Type' => 'application/json'})
      rescue OpenSSL::SSL::SSLError
        raise Bosh::Director::ConfigServerSSLError, 'Config Server SSL error'
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

    def build_uri(name)
      URI.join(@config_server_uri, URI.escape('v1/data/' + name))
    end
  end
end