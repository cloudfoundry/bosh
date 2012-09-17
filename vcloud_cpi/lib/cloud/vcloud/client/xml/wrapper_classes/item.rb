module VCloudCloud
  module Client
    module Xml
      class Item < Wrapper

        def add_rasd(name)
          raise "Cannot add duplicate RASD element \"#{name}\" to Item." if !get_rasd(name).nil?
          add_child(name, 'rasd', RASD)
        end

        def edit_link
          get_nodes('Link', {'rel' => 'edit'}, true).pop
        end

        def get_rasd(name)
          get_nodes(name, nil, true, RASD).pop
        end

        def get_rasd_content(name)
          node = get_rasd(name)
          return node.content if !node.nil?
          nil
        end

        def set_rasd(name, value)
          node = get_rasd(name)
          raise "Cannot set #{name} on Item.  The RASD element does not exist." if node.nil?
          node.content = value
        end

      end
    end
  end
end