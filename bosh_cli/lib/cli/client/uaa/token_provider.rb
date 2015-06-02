module Bosh
  module Cli
    module Client
      module Uaa
        class TokenProvider
          def initialize(ssl_ca_file, config_token, env, director_client)
            @config_token = config_token
            @auth_info = Bosh::Cli::Client::Uaa::AuthInfo.new(director_client, env, ssl_ca_file)
          end

          def token
            unless @auth_info.client_auth?
              return @config_token
            end

            uaa_client = Bosh::Cli::Client::Uaa::Client.new(@auth_info)
            access_info = uaa_client.login({})
            access_info.auth_header if access_info
          end
        end
      end
    end
  end
end



