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
            @auth_info.validate!

            token_issuer = CF::UAA::TokenIssuer.new(
              @auth_info.url,
              @auth_info.client_id,
              @auth_info.client_secret,
              { ssl_ca_file: @auth_info.ssl_ca_file }
            )

            token = token_issuer.client_credentials_grant
            decoded = @token_decoder.decode(token)

            username = decoded['client_id'] if decoded

            AccessInfo.new(username, token.auth_header)
          end
        end
      end
    end
  end
end
