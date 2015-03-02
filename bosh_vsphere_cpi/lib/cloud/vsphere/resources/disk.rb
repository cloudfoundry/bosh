module VSphereCloud
  class Resources
    class Disk
      attr_reader :datastore, :size_in_mb, :path, :cid

      def initialize(cid, size_in_mb, datastore, path)
        @cid = cid
        @size_in_mb = size_in_mb
        @datastore = datastore
        @path = path
      end

      def attach_spec(controller_key)
        DiskConfig.new(datastore.name, path, controller_key, size_in_mb).
          spec(independent: true)
      end
    end
  end
end
