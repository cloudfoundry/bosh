module VSphereCloud
  class Resources
    class DiskWithoutDatastore
      attr_reader :size_in_kb

      def initialize(size_in_kb)
        @size_in_kb = size_in_kb
      end

      def size_in_mb
        @size_in_kb / 1024
      end
    end

    class Disk < DiskWithoutDatastore
      attr_reader :datastore, :size_in_kb, :path, :uuid

      def initialize(uuid, size_in_kb, datastore, path)
        @uuid = uuid
        @size_in_kb = size_in_kb
        @datastore = datastore
        @path = path
      end

      def attach_spec(controller_key)
        DiskConfig.new(datastore.name, path, controller_key, size_in_kb).
          spec(independent: true)
      end
    end
  end
end
