require 'cli/errors'

module Bosh
  module Cli
    module Client
      module Uaa
        class Options < Struct.new(:url, :ssl_ca_file, :client_id, :client_secret)
          class ValidationError < Bosh::Cli::CliError; end

          def self.parse(cli_options, auth_options, env)
            url = auth_options.fetch('url')
            ssl_ca_file = cli_options[:ca_cert]
            client_id, client_secret = env['BOSH_CLIENT'], env['BOSH_CLIENT_SECRET']

            options = new(url, ssl_ca_file, client_id, client_secret)
            options.validate!
            options
          end

          def client_auth?
            !client_id.nil? && !client_secret.nil?
          end

          def validate!
            unless URI.parse(url).instance_of?(URI::HTTPS)
              raise ValidationError.new('HTTPS protocol is required')
            end
          end
        end
      end
    end
  end
end

