module VCloudCloud
  module Client
    module Xml
      class DiskAttachOrDetachParams < Wrapper

        def disk_href=(value)
          disk = get_nodes('Disk').pop
          disk['href'] = value.to_s
        end

      end
    end
  end
end
