module VCloudSdk
  module Xml

    class UploadVAppTemplateParams < Wrapper
      def name=(name)
        @root["name"] = name
      end
    end

  end
end
