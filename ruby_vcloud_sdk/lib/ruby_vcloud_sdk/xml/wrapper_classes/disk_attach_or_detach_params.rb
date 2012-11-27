module VCloudSdk
  module Xml

    class DiskAttachOrDetachParams < Wrapper
      def disk_href=(value)
        disk = get_nodes("Disk").first
        disk["href"] = value.to_s
      end
    end

  end
end
