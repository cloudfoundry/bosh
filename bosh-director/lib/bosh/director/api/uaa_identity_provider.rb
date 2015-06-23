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
          UaaUser.new(token, @director_uuid)
        rescue CF::UAA::DecodeError, CF::UAA::AuthError => e
          raise AuthenticationError, e.message
        end
      end

      class UaaUser

        attr_reader :token

        def initialize(token, director_uuid)
          @token = token
          @director_uuid = director_uuid
        end

        def username
          @token['user_name'] || @token['client_id']
        end

        def has_access?(requested_access)
          if @token['scope']
            if token_has_admin_scope?(@token['scope'])
              return true
            end

            if requested_access == :read && token_has_read_scope?(@token['scope'])
              return true
            end
          end

          false
        end

        private

        def token_has_read_scope?(token_scope)
          token_scope.include?('bosh.read') || token_scope.include?("bosh.#{@director_uuid}.read")
        end

        def token_has_admin_scope?(token_scope)
          token_scope.include?('bosh.admin') || token_scope.include?("bosh.#{@director_uuid}.admin")
        end
      end
    end
  end
end
