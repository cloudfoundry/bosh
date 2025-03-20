module Bosh::Director::ConfigServer
  class AuthHTTPClient
    def initialize
      config_server_hash = Bosh::Director::Config.config_server

      @config_server_uri = URI(config_server_hash['url'])
      @http = Net::HTTP.new(@config_server_uri.hostname, @config_server_uri.port)
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      ca_cert_path = config_server_hash['ca_cert_path']
      set_cert_store(ca_cert_path)

      @auth_provider = Bosh::Director::ConfigServer::UAAAuthProvider.new(config_server_hash['uaa'], Bosh::Director::Config.logger)
      @token = @auth_provider.get_token
    end

    def get(path, initheader = nil, dest = nil, &block)
      header = initheader || {}

      auth_retryable.retryer do |try_num, _|
        refresh_token if try_num > 1
        header['Authorization'] = @token.auth_header
        response = @http.get(path, header, dest, &block)
        raise Bosh::Director::UAAAuthorizationError if response.kind_of? Net::HTTPUnauthorized
        response
      end
    end

    def post(path, data, initheader = nil, dest = nil, &block)
      header = initheader || {}

      auth_retryable.retryer do |try_num, _|
        refresh_token if try_num > 1
        header['Authorization'] = @token.auth_header
        response = @http.post(path, data, header, dest, &block)
        raise Bosh::Director::UAAAuthorizationError if response.kind_of? Net::HTTPUnauthorized
        response
      end
    end

    private

    def refresh_token
      @token = @auth_provider.get_token
    end

    def auth_retryable
      handled_exceptions = [
          Bosh::Director::UAAAuthorizationError,
      ]
      Bosh::Common::Retryable.new({sleep: 0, tries: 2, on: handled_exceptions})
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
  end
end