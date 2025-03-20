require 'uaa'
require 'net/http'

module Bosh::Director::ConfigServer
  class UAAAuthProvider
    def initialize(config, logger)
      @client_id = config['client_id'].to_s
      @client_secret = config['client_secret'].to_s
      @url = config['url'].to_s
      @ca_cert_path = config['ca_cert_path'].to_s

      @logger = logger
    end

    def get_token
      UAAToken.new(@client_id, @client_secret, @url, @ca_cert_path, @logger)
    end
  end

  private

  class UAAToken
    def initialize(client_id, client_secret, uaa_url, ca_cert_path, logger)
      options = {}

      if File.exist?(ca_cert_path) && !File.read(ca_cert_path).strip.empty?
        options[:ssl_ca_file] = ca_cert_path
      else
        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths
        options[:ssl_cert_store] = cert_store
      end

      @uaa_url = uaa_url
      @uaa_token_issuer = CF::UAA::TokenIssuer.new(
        uaa_url,
        client_id,
        client_secret,
        options,
      )
      @logger = logger
    end

    def auth_header
      fetch unless @uaa_token
      @uaa_token ? @uaa_token.auth_header : nil
    end

    private

    def retryable
      handled_exceptions = [
          SocketError,
          Errno::ECONNREFUSED,
          Errno::ETIMEDOUT,
          Errno::ECONNRESET,
          ::Timeout::Error,
          Net::HTTPRetriableError,
          OpenSSL::SSL::SSLError,
      ]
      Bosh::Common::Retryable.new({sleep: 0, tries: 3, on: handled_exceptions})
    end

    def fetch
      @uaa_token = retryable.retryer do
        @uaa_token_issuer.client_credentials_grant
      end
      @token_data = decode
    rescue CF::UAA::SSLException => e
      error_message = "Failed to obtain valid token from UAA: Invalid SSL Cert for '#{@uaa_url}'"
      @logger.error("#{error_message}. Error thrown: #{e.inspect}")
      raise Bosh::Director::UAAAuthorizationError, error_message
    rescue Exception => e
      error_message = "Failed to obtain valid token from UAA: #{e.inspect}"
      @logger.error(error_message)
      raise Bosh::Director::UAAAuthorizationError, error_message
    end

    def decode
      access_token = @uaa_token.info['access_token'] || @uaa_token.info[:access_token]
      CF::UAA::TokenCoder.decode(
        access_token,
        {verify: false},
        nil, nil)
    end
  end
end
