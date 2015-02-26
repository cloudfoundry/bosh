module VSphereCloud
  class Resources
    class ClusterWithDisks
      attr_reader :disks, :cluster

      def initialize(cluster, disks)
        @cluster = cluster
        @disks = disks
      end

      def total_disk_size_in_mb
        disks.map(&:size_in_mb).inject(0, :+)
      end
    end
  end
end
