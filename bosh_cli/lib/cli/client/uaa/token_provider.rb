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
            config_access_token = @config.access_token(@target)

            if @auth_info.client_auth?
              access_info = client_access_info(config_access_token)
            else
              access_info = password_access_info(config_access_token)
            end

            access_info.auth_header if access_info
          end

          private

          def uaa_client
            @uaa_client ||= Bosh::Cli::Client::Uaa::Client.new(@target, @auth_info, @config)
          end

          def client_access_info(config_access_token)
            unless config_access_token
              return uaa_client.access_info({})
            end

            access_info = ClientAccessInfo.from_config(config_access_token, nil, @token_decoder)
            return nil unless access_info

            if access_info.was_issued_for?(@auth_info.client_id)
              return refresh_if_needed(access_info)
            end
            uaa_client.access_info({})
          end

          def password_access_info(config_access_token)
            return nil unless config_access_token

            access_info = PasswordAccessInfo.from_config(config_access_token, @config.refresh_token(@target), @token_decoder)
            return nil unless access_info

            refresh_if_needed(access_info)
          end

          def refresh_if_needed(access_info)
            if access_info.expires_soon?
              uaa_client.refresh(access_info)
            else
              access_info
            end
          end
        end
      end
    end
  end
end



