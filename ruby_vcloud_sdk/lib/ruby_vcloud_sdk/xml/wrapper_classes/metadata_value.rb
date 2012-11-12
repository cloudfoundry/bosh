module VCloudSdk
  module Xml

    class MetadataValue < Wrapper
      def value
        get_nodes("Value").first.content
      end

      def value=(v)
        get_nodes("Value").first.content = v
      end
    end

  end
end
