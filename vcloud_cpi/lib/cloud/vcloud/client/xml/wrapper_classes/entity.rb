module VCloudCloud
  module Client
    module Xml
        class Entity < Wrapper
          def link
            get_nodes("Link").pop
          end

        end
    end
  end
end