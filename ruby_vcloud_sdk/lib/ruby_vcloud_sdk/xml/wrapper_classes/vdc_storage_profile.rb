module VCloudSdk
  module Xml

    class VdcStorageProfile < Wrapper
      def name
        @root["name"]
      end

      def name=(value)
        @root["name"] = value
      end
    end

  end
end
