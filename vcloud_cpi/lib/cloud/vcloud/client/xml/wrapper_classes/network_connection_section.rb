module VCloudCloud
  module Client
    module Xml
      class NetworkConnectionSection < Wrapper
        def add_item(item)
          link_node = get_nodes('Link').pop
          link_node.node.before(item.node)
        end

        def edit_link
          get_nodes('Link', {'rel' => 'edit'}, true).pop
        end

        def network_connections
          get_nodes('NetworkConnection')
        end

        def network_connection(index)
          net = network_connections.find{|n| n.network_connection_index == index.to_s}
          raise "Network connection #{index} does not exist." if net.nil?
          net
        end

        # This will be nil if there are no network connections
        def primary_network_connection_index
          node = get_nodes('PrimaryNetworkConnectionIndex').pop
          if node.nil?
            nil
          else
            node.content
          end
        end

        def primary_network_connection_index=(index)
          get_nodes('PrimaryNetworkConnectionIndex').pop.content = index
        end

        def remove_network_connection(index)
          connection = network_connection(index)
          if !connection.nil?
            connection.node.remove
            reconcile_primary_network()
          else
            raise "Cannot remove network connection.  Network connection #{index} does not exist."
          end
        end

        private

        def reconcile_primary_network()
          new_primary = network_connections.pop
          if !new_primary.nil?
            self.primary_network_connection_index = new_primary.network_connection_index
          else
            primary = get_nodes('PrimaryNetworkConnectionIndex').pop
            primary.node.remove if !primary.nil?
          end
        end

      end
    end
  end
end
