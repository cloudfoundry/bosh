module Bosh
  module Director
    module Api
      class UAAIdentityProvider
        def initialize(options)
          @url = options.fetch('url')
          Config.logger.debug "Initializing UAA Identity provider with url #{@url}"
          config = {
            url: @url,
            resource_id: ['bosh_cli'],
            symmetric_secret: options['key']
          }
          @token_decoder = UAATokenDecoder.new(config)
        end

        def client_info
          {
            'type' => 'uaa',
            'options' => {
              'url' => @url
            }
          }
        end

        def corroborate_user(request_env)
          auth_header = request_env['HTTP_AUTHORIZATION']
          token = @token_decoder.decode_token(auth_header)
          token['user_name']
        rescue UAATokenDecoder::BadToken => e
          raise AuthenticationError, e.message
        end
      end
    end
  end
end
