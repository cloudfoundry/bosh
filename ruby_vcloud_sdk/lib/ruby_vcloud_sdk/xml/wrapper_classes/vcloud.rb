module VCloudSdk
  module Xml

    class VCloud < Wrapper
      def organizations
        get_nodes("OrganizationReference")
      end

      def organization(name)
        get_nodes("OrganizationReference", {"name" => name}).first
      end
    end

  end
end
