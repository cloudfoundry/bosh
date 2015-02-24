module VSphereCloud
  class Resources
    class Disk < Struct.new(:uuid, :size_in_kb, :datastore, :path)
      def attach_spec(controller_key)
        DiskConfig.new(datastore.name, path, controller_key, size_in_kb).
          spec(independent: true)
      end

      def size_in_mb
        size_in_kb / 1024
      end
    end
  end
end
