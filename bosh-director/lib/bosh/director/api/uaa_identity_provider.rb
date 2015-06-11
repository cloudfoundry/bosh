require 'uaa'

module Bosh
  module Director
    module Api
      class UAAIdentityProvider
        def initialize(options)
          @url = options.fetch('url')
          Config.logger.debug "Initializing UAA Identity provider with url #{@url}"
          @token_coder = CF::UAA::TokenCoder.new(skey: options.fetch('symmetric_key', nil), pkey: options.fetch('public_key', nil), scope: [])
        end

        def client_info
          {
            'type' => 'uaa',
            'options' => {
              'url' => @url
            }
          }
        end

        def corroborate_user(request_env)
          auth_header = request_env['HTTP_AUTHORIZATION']
          token = @token_coder.decode(auth_header)
          token['user_name'] || token['client_id']
        rescue CF::UAA::DecodeError, CF::UAA::AuthError => e
          raise AuthenticationError, e.message
        end
      end
    end
  end
end
