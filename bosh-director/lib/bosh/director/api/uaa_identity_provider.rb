require 'uaa'

module Bosh
  module Director
    module Api
      class UAAIdentityProvider
        MAX_TOKEN_EXTENSION_TIME_IN_SECONDS = 3600

        def initialize(options)
          @url = options.fetch('url')
          Config.logger.debug "Initializing UAA Identity provider with url #{@url}"
          @permission_authorizer = Bosh::Director::PermissionAuthorizer.new
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

        def get_user(request_env, options)
          auth_header = request_env['HTTP_AUTHORIZATION']

          if options[:extended_token_timeout]
            request_time_in_seconds = request_env.fetch('HTTP_X_BOSH_UPLOAD_REQUEST_TIME').to_i
            request_time_in_seconds = MAX_TOKEN_EXTENSION_TIME_IN_SECONDS if request_time_in_seconds > MAX_TOKEN_EXTENSION_TIME_IN_SECONDS

            Config.logger.debug("Using extended token timeout, request took #{request_time_in_seconds} seconds")

            token = @token_coder.decode_at_reference_time(auth_header, Time.now.to_i - request_time_in_seconds)
          else
            token = @token_coder.decode(auth_header)
          end

          UaaUser.new(token)
        rescue CF::UAA::DecodeError, CF::UAA::AuthError => e
          raise AuthenticationError, e.message
        end

        def valid_access?(user, requested_access)
          if user.scopes
            required_scopes = required_scopes(requested_access)
            # Here we verify that the user *may* have the ability to perform the request.
            # If the user has admin then it is known the user can do basically anything.
            # If the user only belongs to a team, we still aren't sure if the user has
            # read/write access to the desired resource, but we will let the request pass.
            # These team scope checks are performed in the controller/supporting code.
            return has_valid_team_scope?(user.scopes) ||
                    @permission_authorizer.has_admin_or_director_scope?(user.scopes) ||
                    @permission_authorizer.contains_requested_scope?(required_scopes, user.scopes)
          end

          false
        end

        def required_scopes(requested_access)
          @permission_authorizer.permissions[requested_access]
        end

        private

        def has_valid_team_scope?(token_scopes)
          !@permission_authorizer.transform_admin_team_scope_to_teams(token_scopes).empty?
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
