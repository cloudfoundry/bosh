module Bosh
  module Cli
    module Client
      module Uaa
        class TokenProvider
          def initialize(cert_path, config_token, env, director_client)
            @cert_path = cert_path
            @config_token = config_token
            @env = env
            @auth_info = Bosh::Cli::Client::Uaa::AuthInfo.new(director_client)
          end

          def token
            options = Options.new(@cert_path, @env)
            unless options.client_auth?
              return @config_token
            end

            token_decoder = TokenDecoder.new
            access_info = ClientTokenIssuer.new(options, @auth_info, token_decoder).access_info({})
            access_info.auth_header
          end
        end
      end
    end
  end
end



