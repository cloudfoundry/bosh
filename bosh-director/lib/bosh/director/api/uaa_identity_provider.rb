require 'uaa'

module Bosh
  module Director
    module Api
      class UAAIdentityProvider
        def initialize(options)
          @token_coder = CF::UAA::TokenCoder.new(skey: options.fetch('key'), audience_ids: ['bosh_cli'])
          @url = options.fetch('url')
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
          token["user_id"]
        rescue CF::UAA::DecodeError, CF::UAA::AuthError => e
          raise AuthenticationError, e.message
        end
      end
    end
  end
end
