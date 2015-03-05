require 'uaa'

module Bosh
  module Cli
    module Client
      class Uaa
        def initialize(options)
          @url = options.fetch('url')
        end

        def prompts
          token_issuer = CF::UAA::TokenIssuer.new(@url, 'bosh_cli')
          token_issuer.prompts.map do |field, (type, display_text)|
            Prompt.new(field, type, display_text)
          end
        end

        class Prompt < Struct.new(:field, :type, :display_text)
          def password?
            type == 'password'
          end
        end
      end
    end
  end
end
