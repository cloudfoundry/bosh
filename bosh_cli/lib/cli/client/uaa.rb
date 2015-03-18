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
            decoded = CF::UAA::TokenCoder.decode(
              token.info['access_token'],
              { verify: false }, # token signature not verified because CLI doesn't have the secret key
              nil, nil)
            full_token = "#{token.info['token_type']} #{token.info['access_token']}"
            { username: decoded['user_name'], token: full_token }
          end
        rescue CF::UAA::BadResponse
          nil
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
