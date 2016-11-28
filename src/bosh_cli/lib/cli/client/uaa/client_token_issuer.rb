require 'cli/client/uaa/access_info'

module Bosh
  module Cli
    module Client
      module Uaa
        class ClientTokenIssuer
          def initialize(auth_info, token_decoder)
            @auth_info = auth_info
            @token_decoder = token_decoder
          end

          def prompts
            {}
          end

          def access_info(_)
            token = token_issuer.client_credentials_grant
            ClientAccessInfo.new(token, @token_decoder)
          end

          def refresh(_)
            # For client credentials there is no refresh token, so obtain access token again
            access_info(_)
          end

          private

          def token_issuer
            @token_issuer ||= CF::UAA::TokenIssuer.new(
              @auth_info.url,
              @auth_info.client_id,
              @auth_info.client_secret,
              { ssl_ca_file: @auth_info.ssl_ca_file }
            )
          end
        end
      end
    end
  end
end
