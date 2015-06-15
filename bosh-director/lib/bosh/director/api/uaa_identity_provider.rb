require 'uaa'

module Bosh
  module Director
    module Api
      class UAAIdentityProvider
        def initialize(options, director_uuid)
          @url = options.fetch('url')
          Config.logger.debug "Initializing UAA Identity provider with url #{@url}"
          @director_uuid = director_uuid
          @token_coder = CF::UAA::TokenCoder.new(skey: options.fetch('symmetric_key', nil), pkey: options.fetch('public_key', nil), scope: [])
        end

        def client_info
          {
            'type' => 'uaa',
            'options' => {
              'url' => @url
            }
          }
        end

        def corroborate_user(request_env, requested_access)
          auth_header = request_env['HTTP_AUTHORIZATION']
          token = @token_coder.decode(auth_header)
          validate_access(token, requested_access)

          token['user_name'] || token['client_id']
        rescue CF::UAA::DecodeError, CF::UAA::AuthError => e
          raise AuthenticationError, e.message
        end

        private

        def validate_access(token, requested_access)
          if token['scope']
            if token['scope'].include?('bosh.admin') || token['scope'].include?("bosh.#{@director_uuid}.admin")
              return
            end

            if requested_access.include?(:read) && token['scope'].include?('bosh.read')
              return
            end
          end

          raise AuthenticationError, 'Requested access is not allowed by the scope'
        end
      end
    end
  end
end
