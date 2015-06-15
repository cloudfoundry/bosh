require 'uaa'

module Bosh::Monitor
  class AuthProvider
    def initialize(auth_info, options)
      @auth_info = auth_info.fetch('user_authentication', {})

      @user = options['user'].to_s
      @password = options['password'].to_s
      @client_id = options['client_id'].to_s
      @client_secret = options['client_secret'].to_s
      @ca_cert = options['ca_cert'].to_s
    end

    def auth_header
      if @auth_info.fetch('type', 'local') == 'uaa'
        uaa_url = @auth_info.fetch('options', {}).fetch('url')
        return nil unless uaa_url

        token = uaa_token_issuer(uaa_url).client_credentials_grant
        return nil unless token

        return token.auth_header
      end

      [@user, @password]
    end

    private

    def uaa_token_issuer(uaa_url)
      @uaa_token_issuer = CF::UAA::TokenIssuer.new(
        uaa_url,
        @client_id,
        @client_secret,
        {ssl_ca_file: @ca_cert}
      )
    end
  end
end
