require 'uaa'

module Bosh::Monitor
  class AuthProvider
    def initialize(auth_info, config, logger)
      @auth_info = auth_info.fetch('user_authentication', {})

      @user = config['user'].to_s
      @password = config['password'].to_s
      @client_id = config['client_id'].to_s
      @client_secret = config['client_secret'].to_s
      @ca_cert = config['ca_cert'].to_s

      @logger = logger
    end

    def auth_header
      if @auth_info.fetch('type', 'local') == 'uaa'
        uaa_url = @auth_info.fetch('options', {}).fetch('url')
        return uaa_token_header(uaa_url)
      end

      [@user, @password]
    end

    private

    def uaa_token_header(uaa_url)
      @uaa_token ||= UAAToken.new(@client_id, @client_secret, uaa_url, @ca_cert, @logger)
      @uaa_token.auth_header
    end
  end

  private

  class UAAToken
    EXPIRATION_DEADLINE_IN_SECONDS = 60

    def initialize(client_id, client_secret, uaa_url, ca_cert, logger)
      @uaa_token_issuer = CF::UAA::TokenIssuer.new(
        uaa_url,
        client_id,
        client_secret,
        {ssl_ca_file: ca_cert}
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
      @logger.error("Failed to obtain token from UAA: #{e.inspect}")
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
