module VCloudSdk
  module Xml
    class Session < Wrapper
      def admin_root
        get_nodes("Link", {"type" =>
          VCloudSdk::Xml::ADMIN_MEDIA_TYPE[:VCLOUD]}).pop
      end

      def entity_resolver
        get_nodes("Link", {"type" =>
          VCloudSdk::Xml::MEDIA_TYPE[:ENTITY]}).pop
      end

    end
  end
end
