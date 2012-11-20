module VCloudSdk
  module Xml

    class MediaInsertOrEjectParams < Wrapper
      def media_href=(value)
        media["href"] = value
      end

      private

      def media
         get_nodes("Media", nil, true).pop
      end
    end

  end
end
