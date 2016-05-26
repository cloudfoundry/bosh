module Bosh
  module Cli
    module Client
      module Uaa
        class TokenDecoder
          def decode(token)
            access_token = token.info['access_token'] || token.info[:access_token]
            CF::UAA::TokenCoder.decode(
              access_token,
              {verify: false}, # token signature not verified because CLI doesn't have the secret key
              nil, nil)
          end
        end
      end
    end
  end
end
