require 'vapp'

module VCloudCloud
  module Client
    module Xml
        class VAppTemplate < VApp
          def files
            get_nodes('File')
          end

          #Files that haven't finished transferring
          def incomplete_files
            files.find_all {|f| f['size'].to_i < 0 || (f['size'].to_i > f['bytesTransferred'].to_i)}
          end

        end
    end
  end
end
