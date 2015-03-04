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

      def disk_sizes_in_other_clusters(other_clusters)
        disks_in_other_clusters = Set.new
        disks_in_other_clusters.merge(
          other_clusters.map(&:disks).flatten.reject do |disk|
            @disks.map(&:cid).include?(disk.cid)
          end
        )
        disks_in_other_clusters.map(&:size_in_mb)
      end
    end
  end
end
