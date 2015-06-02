module Bosh
  module Cli
    module Client
      module Uaa
        class AccessInfo < Struct.new(:username, :auth_header); end
      end
    end
  end
end
