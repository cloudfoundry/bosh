require 'uaa'

module Bosh
  module Director
    module Api
      class UAAIdentityProvider
        MAX_TOKEN_EXTENSION_TIME_IN_SECONDS = 3600

        def initialize(options)
          raise ValidationExtraField if options.has_key?('url') && options.has_key?('urls')
          if options.has_key?('url')
            @urls = [options.fetch('url')]
          else
            @urls = options.fetch('urls')
          end
          Config.logger.debug "Initializing UAA Identity provider with urls #{@urls}"
          @token_coder = CF::UAA::TokenCoder.new(skey: options.fetch('symmetric_key', nil), pkey: options.fetch('public_key', nil), scope: [])
        end

        def supports_api_update?
          false
        end

        def client_info
          {
            'type' => 'uaa',
            'options' => {
              'url' => @urls.first,
              'urls' => @urls
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
      end

      class UaaUser
        attr_reader :token

        def initialize(token)
          @token = token
        end

        def username_or_client
          @token['user_name'] || @token['client_id']
        end

        def client
          @token['client_id']
        end

        def username
          @token['user_name']
        end

        def scopes
          @token['scope']
        end
      end
    end
  end
end
