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

          def access_info(prompt_responses)
            credentials = prompt_responses.select { |_, c| !c.empty? }
            token = @token_issuer.owner_password_credentials_grant(credentials)
            PasswordAccessInfo.new(token, @token_decoder)
          end

          def refresh(access_info)
            token = @token_issuer.refresh_token_grant(access_info.refresh_token)
            PasswordAccessInfo.new(token, @token_decoder)
          end
        end
      end
    end
  end
end
