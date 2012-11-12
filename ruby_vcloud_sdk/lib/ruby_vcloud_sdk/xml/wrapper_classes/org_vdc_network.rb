module VCloudSdk
  module Xml

    class OrgVdcNetwork < Wrapper
      def ip_scope
        get_nodes("IpScope").first
      end
    end

  end
end
