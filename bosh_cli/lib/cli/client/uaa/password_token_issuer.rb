require 'uaa'
require 'cli/client/uaa/prompt'
require 'cli/client/uaa/access_info'

module Bosh
  module Cli
    module Client
      module Uaa
        class PasswordTokenIssuer
          def initialize(options, token_decoder)
            @token_issuer = CF::UAA::TokenIssuer.new(options.url, 'bosh_cli', nil, {ssl_ca_file: options.ssl_ca_file})
            @token_decoder = token_decoder
          end

          def prompts
            @token_issuer.prompts.map do |field, (type, display_text)|
              Prompt.new(field, type, display_text)
            end
          end

          def access_info(credentials)
            credentials = credentials.select { |_, c| !c.empty? }
            token = @token_issuer.owner_password_credentials_grant(credentials)
            decoded = @token_decoder.decode(token)

            username = decoded['user_name'] if decoded
            access_token = "#{token.info['token_type']} #{token.info['access_token']}"

            AccessInfo.new(username, access_token)
          end
        end
      end
    end
  end
end
