module VCloudCloud
  module Client
    module Xml
        class File < Wrapper

          def upload_link
            get_nodes('Link', {'rel'=>'upload:default'}).pop
          end
        end
    end
  end
end