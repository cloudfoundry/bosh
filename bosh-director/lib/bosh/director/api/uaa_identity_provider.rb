require 'uaa'

module Bosh
  module Director
    module Api
      class UAAIdentityProvider
        def initialize(options, director_uuid_provider)
          @url = options.fetch('url')
          Config.logger.debug "Initializing UAA Identity provider with url #{@url}"
          @director_uuid = director_uuid_provider.uuid
          @token_coder = CF::UAA::TokenCoder.new(skey: options.fetch('symmetric_key', nil), pkey: options.fetch('public_key', nil), scope: [])
        end

        def supports_api_update?
          false
        end

        def client_info
          {
            'type' => 'uaa',
            'options' => {
              'url' => @url
            }
          }
        end

        def get_user(request_env)
          auth_header = request_env['HTTP_AUTHORIZATION']
          token = @token_coder.decode(auth_header)
          UaaUser.new(token)
        rescue CF::UAA::DecodeError, CF::UAA::AuthError => e
          raise AuthenticationError, e.message
        end

        def valid_access?(user, requested_access)
          if user.scopes
            required_scopes = required_scopes(requested_access)
            return has_admin_scope?(user.scopes) || contains_requested_scope?(required_scopes, user.scopes)
          end

          false
        end

        def required_scopes(requested_access)
          permissions[requested_access]
        end

        private

        def permissions
          {
            :read  => ['bosh.admin', "bosh.#{@director_uuid}.admin", 'bosh.read', "bosh.#{@director_uuid}.read"],
            :write => ['bosh.admin', "bosh.#{@director_uuid}.admin"]
          }
        end

        def has_admin_scope?(token_scopes)
          !(intersect(permissions[:write], token_scopes).empty?)
        end

        def contains_requested_scope?(valid_scopes, token_scopes)
          return false unless valid_scopes
          !(intersect(valid_scopes, token_scopes).empty?)
        end

        def intersect(valid_scopes, token_scopes)
          valid_scopes & token_scopes
        end
      end

      class UaaUser
        attr_reader :token

        def initialize(token)
          @token = token
        end

        def username
          @token['user_name'] || @token['client_id']
        end

        def scopes
          @token['scope']
        end
      end
    end
  end
end
