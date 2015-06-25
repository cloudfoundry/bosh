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
          def initialize(target, auth_info, config)
            @target = target
            @auth_info = auth_info
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

          def access_info(prompt_responses)
            with_save { @token_issuer.access_info(prompt_responses) }
          rescue CF::UAA::TargetError => e
            err("Failed to log in: #{e.info['error_description']}")
          rescue CF::UAA::BadResponse
            nil
          end

          def refresh(access_info)
            @token_issuer.refresh(access_info)
          rescue CF::UAA::TargetError
            nil
          end

          private

          def with_save
            access_info = yield
            if access_info.auth_header && !@auth_info.client_auth?
              @config.set_credentials(@target, access_info.to_hash)
              @config.save
            end

            access_info
          end
        end
      end
    end
  end
end
