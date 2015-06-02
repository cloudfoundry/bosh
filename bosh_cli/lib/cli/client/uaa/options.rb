module Bosh
  module Cli
    module Client
      module Uaa
        class Options
          attr_reader :ssl_ca_file, :client_id, :client_secret

          def initialize(ssl_ca_file, env)
            @client_id, @client_secret = env['BOSH_CLIENT'], env['BOSH_CLIENT_SECRET']
            @ssl_ca_file = ssl_ca_file
          end

          def client_auth?
            !@client_id.nil? && !@client_secret.nil?
          end
        end
      end
    end
  end
end

