module Bosh
  module Cli
    module Client
      module Uaa
        class Prompt < Struct.new(:field, :type, :display_text)
          def password?
            type == 'password'
          end
        end
      end
    end
  end
end
