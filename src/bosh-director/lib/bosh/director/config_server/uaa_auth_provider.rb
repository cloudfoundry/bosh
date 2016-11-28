require 'uaa'

module Bosh::Director
  class UAAAuthProvider

    def initialize(config, logger)
      @client_id = config['client_id'].to_s
      @client_secret = config['client_secret'].to_s
      @url = config['url'].to_s
      @ca_cert_path = config['ca_cert_path'].to_s

      @logger = logger
    end

    def auth_header
      @uaa_token ||= UAAToken.new(@client_id, @client_secret, @url, @ca_cert_path, @logger)
      @uaa_token.auth_header
    end
  end

  private

  class UAAToken
    EXPIRATION_DEADLINE_IN_SECONDS = 60

    def initialize(client_id, client_secret, uaa_url, ca_cert_path, logger)
      options = {}

      if File.exist?(ca_cert_path) && !File.read(ca_cert_path).strip.empty?
        options[:ssl_ca_file] = ca_cert_path
      else
        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths
        options[:ssl_cert_store] = cert_store
      end

      @uaa_token_issuer = CF::UAA::TokenIssuer.new(
        uaa_url,
        client_id,
        client_secret,
        options,
      )
      @logger = logger
    end

    def auth_header
      if @uaa_token && !expires_soon?
        return @uaa_token.auth_header
      end

      fetch

      @uaa_token ? @uaa_token.auth_header : nil
    end

    private

    def expires_soon?
      expiration = @token_data[:exp] || @token_data['exp']
      (Time.at(expiration).to_i - Time.now.to_i) < EXPIRATION_DEADLINE_IN_SECONDS
    end 

    def fetch
      @uaa_token = @uaa_token_issuer.client_credentials_grant
      @token_data = decode
    rescue => e
      error_message = "Failed to obtain valid token from UAA: #{e.inspect}"
      @logger.error(error_message)
      raise UAAAuthorizationError, error_message
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
