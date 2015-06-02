require 'cli/errors'

module Bosh
  module Cli
    module Client
      module Uaa
        class AuthInfo
          class ValidationError < Bosh::Cli::CliError; end

          def initialize(director)
            @director = director
          end

          def uaa?
            auth_info['type'] == 'uaa'
          end

          def url
            auth_info.fetch('options', {}).fetch('url', nil)
          end

          def validate!
            return unless uaa?

            unless URI.parse(url).instance_of?(URI::HTTPS)
              raise ValidationError.new('HTTPS protocol is required')
            end
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

