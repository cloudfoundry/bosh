require 'cli/client/uaa/client'

module Bosh
  module Cli
    module Client
      module Uaa
        class TokenProvider
          def initialize(auth_info, config_token, token_decoder)
            @auth_info = auth_info
            @config_token = config_token
            @token_decoder = token_decoder
          end

          def token
            unless @auth_info.client_auth?
              return @config_token
            end

            if @config_token
              uaa_token = parse_uaa_token
              if uaa_token
                decoded = @token_decoder.decode(uaa_token)
                if decoded['client_id'] == @auth_info.client_id
                  return @config_token
                end
              end
            end

            access_info = Bosh::Cli::Client::Uaa::Client.new(@auth_info).login({})
            access_info.auth_header if access_info
          end

          private

          def parse_uaa_token
            token_type, access_token = @config_token.split(' ')
            if token_type && access_token
              CF::UAA::TokenInfo.new({
                'access_token' => access_token,
                'token_type' => token_type,
              })
            end
          end
        end
      end
    end
  end
end



