module Bosh
  module Cli
    module Client
      class UaaCredentials
        def initialize(token_provider)
          @token_provider = token_provider
        end

        def username
          @token_provider.username
        end

        def authorization_header
          @token_provider.token
        end

        def refresh
          @token_provider.refresh
          true
        end
      end

      class BasicCredentials
        def initialize(username, password)
          @username = username
          @password = password
        end

        def username
          @username
        end

        def authorization_header
          'Basic ' + Base64.encode64("#{@username}:#{@password}").strip
        end

        def refresh
          false
        end
      end
    end
  end
end
