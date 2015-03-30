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
          def initialize(options)
            token_decoder = TokenDecoder.new
            if options.client_auth?
              token_issuer = ClientTokenIssuer.new(options, token_decoder)
            else
              token_issuer = PasswordTokenIssuer.new(options, token_decoder)
            end
            @ssl_ca_file = options.ssl_ca_file
            @token_issuer = token_issuer
          end

          def prompts
            @token_issuer.prompts
          rescue CF::UAA::SSLException => e
            raise e unless @ssl_ca_file.nil?
            err('Invalid SSL Cert. Use --ca-cert to specify SSL certificate') #FIXME: the uaa client shouldn't know about 'err'
          end

          def login(credentials)
            @token_issuer.access_info(credentials)
          rescue CF::UAA::TargetError => e
            err("Failed to log in: #{e.info['error_description']}") #FIXME: the uaa client shouldn't know about 'err'
          rescue CF::UAA::BadResponse
            nil
          end
        end
      end
    end
  end
end
