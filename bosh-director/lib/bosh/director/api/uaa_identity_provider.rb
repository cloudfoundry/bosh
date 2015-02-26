require 'uaa'

module Bosh
  module Director
    module Api
      class UAAIdentityProvider
        def initialize(key)
          @token_coder = CF::UAA::TokenCoder.new(skey: key, audience_ids: ['bosh'])
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
