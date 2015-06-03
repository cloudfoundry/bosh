require 'cli/client/uaa/client'

module Bosh
  module Cli
    module Client
      module Uaa
        class TokenProvider
          def initialize(auth_info, config, token_decoder, target)
            @auth_info = auth_info
            @config = config
            @token_decoder = token_decoder
            @target = target
          end

          def token
            config_token = @config.token(@target)

            unless @auth_info.client_auth?
              return config_token
            end

            if config_token
              uaa_token = parse_uaa_token(config_token)
              if uaa_token
                decoded = @token_decoder.decode(uaa_token)
                if decoded['client_id'] == @auth_info.client_id
                  return config_token
                end
              end
            end

            access_info = Bosh::Cli::Client::Uaa::Client.new(@auth_info, @config).login({}, @target)
            access_info.auth_header if access_info
          end

          private

          def parse_uaa_token(config_token)
            token_type, access_token = config_token.split(' ')
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



