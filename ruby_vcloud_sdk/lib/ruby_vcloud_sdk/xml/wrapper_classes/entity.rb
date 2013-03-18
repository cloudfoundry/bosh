module VCloudSdk
  module Xml

    class Entity < Wrapper
      def link
        get_nodes("Link").first
      end
    end

  end
end
