require 'uaa'

module Bosh
  module Cli
    module Client
      class Uaa
        def initialize(options)
          url = options.fetch('url')
          @token_issuer = CF::UAA::TokenIssuer.new(url, 'bosh_cli', nil, {skip_ssl_validation: true})
        end

        def prompts
          @token_issuer.prompts.map do |field, (type, display_text)|
            Prompt.new(field, type, display_text)
          end
        end

        def login(credentials)
          token = @token_issuer.implicit_grant_with_creds(credentials)

          if token
            decoded = TokenCoder.decode(token.info["access_token"], nil, nil, false) #token signature not verified
            { username: decoded["user_name"], token: token.info["access_token"] }
          end
        end

        class Prompt < Struct.new(:field, :type, :display_text)
          def password?
            type == 'password'
          end
        end
      end
    end
  end
end
