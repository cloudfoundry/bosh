module VCloudCloud
  module Client
    module Xml
      class IpScope < Wrapper
        def is_inherited?
          get_nodes('IsInherited').pop.content
        end

        def is_inherited=(value)
          get_nodes('IsInherited').pop.content = value
        end

        def gateway
          get_nodes('Gateway').pop.content
        end

        def gateway=(value)
          get_nodes('Gateway').pop.content = value
        end

        def netmask
          get_nodes('Netmask').pop.content
        end

        def netmask=(value)
          get_nodes('Netmask').pop.content = value
        end

        def start_address
          nodes = get_nodes('StartAddress')
          return nil if nodes.nil?
          node = nodes.pop
          return nil if node.nil?
          return node.content
        end

        def start_address=(value)
          get_nodes('StartAddress').pop.content = value
        end

        def end_address
          nodes = get_nodes('EndAddress')
          return nil if nodes.nil?
          node = nodes.pop
          return nil if node.nil?
          return node.content
        end

        def end_address=(value)
          get_nodes('EndAddress').pop.content = value
        end

      end
    end
  end
end
