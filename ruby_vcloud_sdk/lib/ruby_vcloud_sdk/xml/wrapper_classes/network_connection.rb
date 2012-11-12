module VCloudSdk
  module Xml

    class NetworkConnection < Wrapper
      def network
        @root["network"]
      end

      # Value should be the name of the vApp network to connect to
      def network=(value)
        @root["network"] = value
      end

      def network_connection_index
        get_nodes("NetworkConnectionIndex").first.content
      end

      def network_connection_index=(value)
        unless get_nodes("NetworkConnectionIndex").first
          index_node = create_child("NetworkConnectionIndex")
          add_child(index_node)
        end
        get_nodes("NetworkConnectionIndex").first.content = value
      end

      def ip_address
        get_nodes("IpAddress").first.content
      end

      def ip_address=(value)
        # When addressing mode is other than MANUAL this node does not exist.
        unless get_nodes("IpAddress").first
          # must be after network connection index
          index_node = get_nodes("NetworkConnectionIndex").first
          ip_node = create_child("IpAddress")
          index_node.node.after(ip_node)
        end
        get_nodes("IpAddress").first.content = value
      end

      def is_connected
        get_nodes("IsConnected").first.content
      end

      def is_connected=(value)
        get_nodes("IsConnected").first.content = value
      end

      def mac_address
        get_nodes("MACAddress").first.content
      end

      def mac_address=(value)
        get_nodes("MACAddress").first.content = value
      end

      def ip_address_allocation_mode
        get_nodes("IpAddressAllocationMode").first.content
      end

      def ip_address_allocation_mode=(value)
        if !IP_ADDRESSING_MODE.values.include?(value)
          raise ArgumentError, "Invalid IP addressing mode.  Valid modes " +
              "are: #{IP_ADDRESSING_MODE.values.join(" ")}"
        end
        get_nodes("IpAddressAllocationMode").first.content = value
      end
    end

  end
end
