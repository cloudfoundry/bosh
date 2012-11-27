module VCloudSdk
  module Xml

    class File < Wrapper
      def upload_link
        get_nodes("Link", {"rel"=>"upload:default"}).first
      end
    end

  end
end
