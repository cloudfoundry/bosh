module VCloudCloud
  module Client
    module Xml
      class MetadataValue < Wrapper
        def value
          get_nodes('Value').pop.content
        end

        def value=(v)
          get_nodes('Value').pop.content = v
        end

      end
    end
  end
end