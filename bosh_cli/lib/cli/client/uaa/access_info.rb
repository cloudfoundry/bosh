module Bosh
  module Cli
    module Client
      module Uaa
        class AccessInfo < Struct.new(:username, :token); end
      end
    end
  end
end
