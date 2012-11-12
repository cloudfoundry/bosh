module VCloudSdk
  module Xml
    class CatalogItem < Wrapper
      def name=(name)
        @root['name'] = name
      end

      def remove_link
        get_nodes('Link', {'rel' => 'remove'}, true).pop
      end

      def entity=(entity)
        entity_node = get_nodes('Entity').pop
        entity_node['name'] = entity.name
        entity_node['id'] = entity.urn
        entity_node['href'] = entity.href
        entity_node['type'] = entity.type
      end

      def entity
        get_nodes('Entity').pop
      end
    end
  end
end
