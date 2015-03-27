require 'uaa'
require 'uri'

module Bosh
  module Cli
    module Client
      class Uaa
        class AccessInfo < Struct.new(:username, :token); end

        def initialize(options, ssl_ca_file)
          url = options.fetch('url')
          unless URI.parse(url).instance_of?(URI::HTTPS)
            err('Failed to connect to UAA, HTTPS protocol is required')
          end
          @ssl_ca_file = ssl_ca_file

          token_decoder = TokenDecoder.new
          if ENV['BOSH_CLIENT'] && ENV['BOSH_CLIENT_SECRET']
            @token_issuer = ClientTokenIssuer.new(url, ssl_ca_file, token_decoder)
          else
            @token_issuer = PasswordTokenIssuer.new(url, ssl_ca_file, token_decoder)
          end
        end

        def prompts
          @token_issuer.prompts
        rescue CF::UAA::SSLException => e
          raise e unless @ssl_ca_file.nil?
          err('Invalid SSL Cert. Use --ca-cert to specify SSL certificate')
        end

        def login(credentials)
          @token_issuer.access_info(credentials)
        rescue CF::UAA::TargetError => e
          err("Failed to log in: #{e.info['error_description']}")
        rescue CF::UAA::BadResponse
          nil
        end

        private

        class ClientTokenIssuer
          def initialize(url, ssl_ca_file, token_decoder)
            @token_issuer = CF::UAA::TokenIssuer.new(url, ENV['BOSH_CLIENT'], ENV['BOSH_CLIENT_SECRET'], {ssl_ca_file: ssl_ca_file})
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

        class PasswordTokenIssuer
          def initialize(url, ssl_ca_file, token_decoder)
            @token_issuer = CF::UAA::TokenIssuer.new(url, 'bosh_cli', nil, {ssl_ca_file: ssl_ca_file})
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

        class Prompt < Struct.new(:field, :type, :display_text)
          def password?
            type == 'password'
          end
        end

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
