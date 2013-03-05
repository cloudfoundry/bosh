module VCloudSdk
  module Xml

    class NetworkConnectionSection < Wrapper
      def add_item(item)
        link_node = get_nodes("Link").first
        link_node.node.before(item.node)
      end

      def edit_link
        get_nodes("Link", {"rel" => "edit"}, true).first
      end

      def network_connections
        get_nodes("NetworkConnection")
      end

      def network_connection(index)
        net = network_connections.find {
          |n| n.network_connection_index == index.to_s }
        unless net
          raise ObjectNotFoundError, "Network connection #{index} does not exist."
        end
        net
      end

      # This will be nil if there are no network connections
      def primary_network_connection_index
        node = get_nodes("PrimaryNetworkConnectionIndex").first
        if node.nil?
          nil
        else
          node.content
        end
      end

      def primary_network_connection_index=(index)
        get_nodes("PrimaryNetworkConnectionIndex").first.content = index
      end

      def remove_network_connection(index)
        connection = network_connection(index)
        if connection
          connection.node.remove
          reconcile_primary_network()
        else
          raise ObjectNotFoundError,
            "Cannot remove network connection #{index}: does not exist."
        end
      end

      private

      def reconcile_primary_network()
        new_primary = network_connections.first
        if new_primary
          self.primary_network_connection_index =
            new_primary.network_connection_index
        else
          primary = get_nodes("PrimaryNetworkConnectionIndex").first
          primary.node.remove if primary
        end
      end
    end

  end
end
