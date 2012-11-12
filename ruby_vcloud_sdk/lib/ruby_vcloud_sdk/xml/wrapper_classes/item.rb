module VCloudSdk
  module Xml

    class Item < Wrapper
      def add_rasd(name)
        raise "Cannot add duplicate RASD element #{name}." if get_rasd(name)
        add_child(name, "rasd", RASD)
      end

      def edit_link
        get_nodes("Link", {"rel" => "edit"}, true).first
      end

      def get_rasd(name)
        get_nodes(name, nil, true, RASD).first
      end

      def get_rasd_content(name)
        node = get_rasd(name)
        return node.content if node
        nil
      end

      def set_rasd(name, value)
        node = get_rasd(name)
        raise "The RASD element #{name} does not exist." unless node
        node.content = value
      end
    end

  end
end
