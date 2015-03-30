module Bosh
  module Cli
    module Client
      module Uaa
        class TokenDecoder
          def decode(token)
            CF::UAA::TokenCoder.decode(
              token.info['access_token'],
              {verify: false}, # token signature not verified because CLI doesn't have the secret key
              nil, nil)
          end
        end
      end
    end
  end
end
