require 'cli/errors'

module Bosh
  module Cli
    module Client
      module Uaa
        class AuthInfo
          class ValidationError < Bosh::Cli::CliError; end

          attr_reader :ssl_ca_file, :client_id, :client_secret

          def initialize(director, env, ssl_ca_file)
            @director = director
            @client_id, @client_secret = env['BOSH_CLIENT'], env['BOSH_CLIENT_SECRET']
            @ssl_ca_file = ssl_ca_file
          end

          def client_auth?
            if @client_id.nil? && !@client_secret.nil?
              raise ValidationError.new('BOSH_CLIENT is missing')
            end
            if @client_secret.nil? && !@client_id.nil?
              raise ValidationError.new('BOSH_CLIENT_SECRET is missing')
            end

            !@client_id.nil? && !@client_secret.nil?
          end

          def uaa?
            auth_info['type'] == 'uaa'
          end

          def url
            url = auth_info.fetch('options', {}).fetch('url', nil)

            if url
              unless URI.parse(url).instance_of?(URI::HTTPS)
                raise ValidationError.new('HTTPS protocol is required')
              end
            end

            url
          end

          private

          def auth_info
            director_info.fetch('user_authentication', {})
          end

          def director_info
            @director_info ||= @director.get_status
          rescue Bosh::Cli::AuthError
            {}
          end
        end
      end
    end
  end
end

