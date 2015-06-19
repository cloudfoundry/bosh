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
            access_info = get_access_info
            access_info.auth_header if access_info
          end

          def username
            get_access_info.username
          end

          private

          def get_access_info
            if @auth_info.client_auth?
              client_access_info
            else
              password_access_info
            end
          end

          def uaa_client
            @uaa_client ||= Bosh::Cli::Client::Uaa::Client.new(@target, @auth_info, @config)
          end

          def client_access_info
            if !@client_access_info.nil? && @client_access_info.was_issued_for?(@auth_info.client_id)
              @client_access_info = refresh_if_needed(@client_access_info)
            else
              @client_access_info = uaa_client.access_info({})
            end
          end

          def password_access_info
            config_access_token = @config.access_token(@target)
            return nil unless config_access_token

            access_info = PasswordAccessInfo.create(config_access_token, @config.refresh_token(@target), @token_decoder)
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



