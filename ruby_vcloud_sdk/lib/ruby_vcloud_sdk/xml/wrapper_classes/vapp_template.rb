module VCloudSdk
  module Xml

    class VAppTemplate < VApp
      def files
        get_nodes("File")
      end

      # Files that have not finished transferring
      def incomplete_files
        files.find_all {|f| f["size"].to_i < 0 ||
          (f["size"].to_i > f["bytesTransferred"].to_i)}
      end
    end

  end
end
