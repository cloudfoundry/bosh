module VCloudSdk
  module Xml

    class InstantiateVAppTemplateParams < Wrapper
      def name
        @root["name"]
      end

      def description
        get_nodes("Description").first
      end

      def all_eulas_accepted=(value)
        eulas_node = get_nodes("AllEULAsAccepted").first
        eulas_node.content = value
      end

      def name=(name)
        @root["name"] = name
      end

      def description=(desc)
        description.content = desc
      end

      def linked_clone=(value)
        @root["linkedClone"] = value.to_s
      end

      def source=(src)
        source_node = get_nodes("Source").first
        source_node["href"] = src["href"]
        source_node["id"] = src["id"]
        source_node["type"] = src["type"]
        source_node["id"] = src["id"]
      end

      def set_locality=(locality)
        return unless locality

        raise "vApp locality already set." if @local_exists
        @local_exists = true

        locality.each do |k,v|
          node_sp = create_child("SourcedVmInstantiationParams")
          is_source_delete.node.after(node_sp)

          node_sv = add_child("Source", nil, nil, node_sp)
          node_sv["type"] = k.type
          node_sv["name"] = k.name
          node_sv["href"] = k.href

          node_lp = create_child("LocalityParams")
          node_sv.after(node_lp)

          node_re = add_child("ResourceEntity", nil, nil, node_lp)
          node_re["type"] = v.type
          node_re["name"] = v.name
          node_re["href"] = v.href
        end
      end

      private

      def is_source_delete
        get_nodes("IsSourceDelete").first
      end
    end

  end
end
