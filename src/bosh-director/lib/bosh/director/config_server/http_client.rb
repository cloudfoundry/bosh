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
      uri = build_base_uri
      uri.query = URI.escape("name=#{name}")
      get_exception = nil
      begin
        retryable.retryer do |retries, exception|
          get_exception = exception
          @http.get(uri.request_uri, {'Authorization' => @auth_provider.auth_header})
        end
      rescue => e
        e = get_exception.nil? ? e : get_exception
        raise Bosh::Director::ConfigServerSSLError, 'Config Server SSL error' if e.is_a? OpenSSL::SSL::SSLError
        raise e
      end
    end

    def post(body)
      uri = build_base_uri
      post_exception = nil
      begin
        retryable.retryer do |retries, exception|
          get_exception = exception
          @http.post(uri.path, Yajl::Encoder.encode(body), {'Authorization' => @auth_provider.auth_header, 'Content-Type' => 'application/json'})
        end
      rescue => e
        e = post_exception.nil? ? e : post_exception
        raise Bosh::Director::ConfigServerSSLError, 'Config Server SSL error' if e.is_a? OpenSSL::SSL::SSLError
        raise e
      end
    end

    private

    def retryable
      handled_exceptions = [
          SocketError,
          Errno::ECONNREFUSED,
          Errno::ETIMEDOUT,
          Errno::ECONNRESET,
          ::Timeout::Error,
          ::HTTPClient::TimeoutError,
          ::HTTPClient::KeepAliveDisconnected,
          OpenSSL::SSL::SSLError
      ]
      Bosh::Retryable.new({sleep: 0, tries: 3, on: handled_exceptions})
    end

    def set_cert_store(ca_cert_path)
      if ca_cert_path && File.exist?(ca_cert_path) && !File.read(ca_cert_path).strip.empty?
        @http.ca_file = ca_cert_path
      else
        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths
        @http.cert_store = cert_store
      end
    end

    def build_base_uri
      URI.join(@config_server_uri, URI.escape('v1/data'))
    end
  end
end