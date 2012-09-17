module VCloudCloud
  module Client
    module Xml
      class NetworkConfig < Wrapper
        def ip_scope
          get_nodes('IpScope').pop
        end

        def network_name
          @root['networkName']
        end

        def parent_network
          get_nodes('ParentNetwork').pop
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
end