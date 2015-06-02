module Bosh
  module Cli
    module Client
      module Uaa
        class ClientTokenIssuer
          def initialize(options, auth_info, token_decoder)
            @auth_info = auth_info
            @client_id = options.client_id
            @client_secret = options.client_secret
            @ssl_ca_file = options.ssl_ca_file

            @token_decoder = token_decoder
          end

          def prompts
            {}
          end

          def access_info(_)
            @auth_info.validate!

            token_issuer = CF::UAA::TokenIssuer.new(@auth_info.url, @client_id, @client_secret, {ssl_ca_file: @ssl_ca_file})

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
