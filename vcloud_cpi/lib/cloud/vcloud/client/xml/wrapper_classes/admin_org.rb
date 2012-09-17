module VCloudCloud
  module Client
    module Xml
        class AdminOrg < Wrapper
          def vdc(name)
            get_nodes('Vdc', {'name'=>name}).pop
          end

          def catalog(name)
            get_nodes('CatalogReference', {'name'=>name}).pop
          end

        end
    end
  end
end