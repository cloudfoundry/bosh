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
          def initialize(auth_info)
            token_decoder = TokenDecoder.new
            if auth_info.client_auth?
              token_issuer = ClientTokenIssuer.new(auth_info, token_decoder)
            else
              token_issuer = PasswordTokenIssuer.new(auth_info, token_decoder)
            end
            @ssl_ca_file = auth_info.ssl_ca_file
            @token_issuer = token_issuer
          end

          def prompts
            @token_issuer.prompts
          rescue CF::UAA::SSLException => e
            raise e unless @ssl_ca_file.nil?
            err('Invalid SSL Cert. Use --ca-cert option when setting target to specify SSL certificate')
          end

          def login(prompt_responses)
            @token_issuer.access_info(prompt_responses)
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
