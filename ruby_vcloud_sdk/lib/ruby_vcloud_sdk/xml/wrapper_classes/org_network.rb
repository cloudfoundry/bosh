module VCloudSdk
  module Xml
    class OrgNetwork < Wrapper
      def ip_scope
        get_nodes('IpScope').pop
      end

      def fence_mode
        get_nodes('FenceMode').pop.content
      end

      def fence_mode=(value)
        get_nodes('FenceMode').pop.content = value
      end

    end
  end
end
