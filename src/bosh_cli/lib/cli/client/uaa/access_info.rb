module Bosh
  module Cli
    module Client
      module Uaa
        class AccessInfo
          EXPIRATION_DEADLINE_IN_SECONDS = 30

          def initialize(token_info, token_decoder)
            @token_info = token_info
            @token_decoder = token_decoder
          end

          def auth_header
            @token_info.auth_header
          end

          def refresh_token
            @token_info.info[:refresh_token] || @token_info.info['refresh_token']
          end

          def was_issued_for?(other_username)
            username == other_username
          end

          def expires_soon?
            expiration = token_data[:exp] || token_data['exp']
            (Time.at(expiration).to_i - Time.now.to_i) < EXPIRATION_DEADLINE_IN_SECONDS
          end

          def token_data
            @token_data ||= @token_decoder.decode(@token_info)
          end

          def to_hash
            {
              'access_token' => auth_header,
              'refresh_token' => refresh_token
            }
          end
        end

        class ClientAccessInfo < AccessInfo
          def username
            token_data['client_id']
          end
        end

        class PasswordAccessInfo < AccessInfo
          def self.create(full_access_token, refresh_token, token_decoder)
            token_type, access_token = full_access_token.split(' ')
            return nil unless token_type && access_token

            token_info = CF::UAA::TokenInfo.new({
                access_token: access_token,
                refresh_token: refresh_token,
                token_type: token_type,
              })
            new(token_info, token_decoder)
          end

          def username
            token_data['user_name']
          end
        end
      end
    end
  end
end
