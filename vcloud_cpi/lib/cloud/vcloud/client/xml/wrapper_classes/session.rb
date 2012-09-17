module VCloudCloud
  module Client
    module Xml
        class Session < Wrapper
          def admin_root
            get_nodes("Link", {"type" => VCloudCloud::Client::Xml::ADMIN_MEDIA_TYPE[:VCLOUD]}).pop
          end

          def entity_resolver
            get_nodes("Link", {"type" => VCloudCloud::Client::Xml::MEDIA_TYPE[:ENTITY]}).pop
          end

        end
    end
  end
end
