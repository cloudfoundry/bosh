module VCloudSdk
  module Xml

    class Media < Wrapper
      def name
        @root["name"]
      end

      def name=(name)
        @root["name"] = name.to_s
      end

      def size
        @root["size"]
      end

      def size=(size)
        @root["size"] = size.to_s
      end

      def image_type
        @root["imageType"]
      end

      def image_type=(image_type)
        @root["imageType"] = image_type.to_s
      end

      def storage_profile=(storage_profile)
        add_child(storage_profile) unless storage_profile.nil?
      end

      def files
        get_nodes("File")
      end

      # Files that haven"t finished transferring
      def incomplete_files
        files.find_all { |f| f["size"].to_i < 0 ||
          (f["size"].to_i > f["bytesTransferred"].to_i) }
      end

      def delete_link
        get_nodes("Link", {"rel" => "remove"}, true).first
      end

      def running_tasks
        get_nodes("Task", {"status" => "running"})
      end
    end

  end
end
