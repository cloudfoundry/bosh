module VCloudCloud
  module Client
    module Xml
      class NetworkConnection < Wrapper
        def network
          @root['network']
        end

        # Value should be the name of the vApp network to connect to
        def network=(value)
          @root['network'] = value
        end

        def network_connection_index
          get_nodes('NetworkConnectionIndex').pop.content
        end

        def network_connection_index=(value)
          unless get_nodes('NetworkConnectionIndex').pop
            index_node = create_child('NetworkConnectionIndex')
            add_child(index_node)
          end
          get_nodes('NetworkConnectionIndex').pop.content = value
        end

        def ip_address
          get_nodes('IpAddress').pop.content
        end

        def ip_address=(value)
          # When addressing mode is other than MANUAL this node does not exist.
          unless get_nodes('IpAddress').pop
            # must be after network connection index
            index_node = get_nodes('NetworkConnectionIndex').pop
            ip_node = create_child('IpAddress')
            index_node.node.after(ip_node)
          end
          get_nodes('IpAddress').pop.content = value
        end

        def is_connected
          get_nodes('IsConnected').pop.content
        end

        def is_connected=(value)
          get_nodes('IsConnected').pop.content = value
        end

        def mac_address
          get_nodes('MACAddress').pop.content
        end

        def mac_address=(value)
          get_nodes('MACAddress').pop.content = value
        end

        def ip_address_allocation_mode
          get_nodes('IpAddressAllocationMode').pop.content
        end

        def ip_address_allocation_mode=(value)
          raise "Invalid IP addressing mode. "  \
            "Valid IP addressing allocation modes are \
#{IP_ADDRESSING_MODE.values.join(' ')}" if
              !IP_ADDRESSING_MODE.values.include?(value)
          get_nodes('IpAddressAllocationMode').pop.content = value
        end

      end
    end
  end
end
