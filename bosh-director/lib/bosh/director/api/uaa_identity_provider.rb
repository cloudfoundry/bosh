module Bosh
  module Director
    module Api
      class UAAIdentityProvider
        def corroborate_user(request_env)
          raise AuthenticationError
        end
      end
    end
  end
end
