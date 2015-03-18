module Bosh
  module Cli
    module Client
      class UaaCredentials
        def initialize(token)
          @token = token
        end

        def authorization_header
          @token
        end
      end

      class BasicCredentials
        def initialize(username, password)
          @username = username
          @password = password
        end

        def authorization_header
          'Basic ' + Base64.encode64("#{@username}:#{@password}").strip
        end
      end
    end
  end
end
