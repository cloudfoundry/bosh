module Bosh
  module Cli
    module Client
      module Uaa
        class ClientTokenIssuer
          def initialize(options, token_decoder)
            @token_issuer = CF::UAA::TokenIssuer.new(options.url, options.client_id, options.client_secret, {ssl_ca_file: options.ssl_ca_file})
            @token_decoder = token_decoder
          end

          def prompts
            {}
          end

          def access_info(_)
            token = @token_issuer.client_credentials_grant
            decoded = @token_decoder.decode(token)

            username = decoded['client_id'] if decoded
            AccessInfo.new(username, nil)
          end
        end
      end
    end
  end
end
