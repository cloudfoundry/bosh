module VCloudSdk
  module Xml

    class IpScope < Wrapper
      def is_inherited?
        get_nodes("IsInherited").first.content
      end

      def is_inherited=(value)
        get_nodes("IsInherited").first.content = value
      end

      def gateway
        get_nodes("Gateway").first.content
      end

      def gateway=(value)
        get_nodes("Gateway").first.content = value
      end

      def netmask
        get_nodes("Netmask").first.content
      end

      def netmask=(value)
        get_nodes("Netmask").first.content = value
      end

      def start_address
        nodes = get_nodes("StartAddress")
        return nil unless nodes
        node = nodes.first
        return nil unless node
        return node.content
      end

      def start_address=(value)
        get_nodes("StartAddress").first.content = value
      end

      def end_address
        nodes = get_nodes("EndAddress")
        return nil unless nodes
        node = nodes.first
        return nil unless node
        return node.content
      end

      def end_address=(value)
        get_nodes("EndAddress").first.content = value
      end
    end

  end
end
