module VCloudSdk
  module Xml

    class Session < Wrapper
      def admin_root
        get_nodes("Link", {"type" =>
          VCloudSdk::Xml::ADMIN_MEDIA_TYPE[:VCLOUD]}).first
      end

      def entity_resolver
        get_nodes("Link", {"type" =>
          VCloudSdk::Xml::MEDIA_TYPE[:ENTITY]}).first
      end
    end

  end
end
