module VSphereCloud
  class Resources
    class Disk
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

      def size_in_mb
        @size_in_kb / 1024
      end
    end
  end
end
