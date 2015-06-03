require 'uaa'
require 'uri'
require 'cli/client/uaa/client_token_issuer'
require 'cli/client/uaa/password_token_issuer'
require 'cli/client/uaa/token_decoder'

module Bosh
  module Cli
    module Client
      module Uaa
        class Client
          def initialize(auth_info, config)
            token_decoder = TokenDecoder.new
            if auth_info.client_auth?
              token_issuer = ClientTokenIssuer.new(auth_info, token_decoder)
            else
              token_issuer = PasswordTokenIssuer.new(auth_info, token_decoder)
            end
            @ssl_ca_file = auth_info.ssl_ca_file
            @token_issuer = token_issuer
            @config = config
          end

          def prompts
            @token_issuer.prompts
          rescue CF::UAA::SSLException => e
            raise e unless @ssl_ca_file.nil?
            err('Invalid SSL Cert. Use --ca-cert option when setting target to specify SSL certificate')
          end

          def login(prompt_responses, target)
            access_info = @token_issuer.access_info(prompt_responses)

            if access_info.auth_header
              @config.set_credentials(target, { 'token' => access_info.auth_header })
              @config.save
            end

            access_info
          rescue CF::UAA::TargetError => e
            err("Failed to log in: #{e.info['error_description']}")
          rescue CF::UAA::BadResponse
            nil
          end
        end
      end
    end
  end
end
