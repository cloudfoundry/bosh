module VCloudCloud
  module Client
    module Xml
        class UploadVAppTemplateParams < Wrapper
          def name=(name)
            @root['name'] = name
          end
        end
    end
  end
end