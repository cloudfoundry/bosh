module VSphereCloud
  class ClusterLocality
    def initialize(clusters)
      @clusters = clusters
    end

    def clusters_ordered_by_disk_size(disks)
      @clusters.map do |cluster|
        disks_in_this_cluster = disks.reject do |disk|
          cluster.persistent(disk.datastore.name).nil?
        end
        Resources::ClusterWithDisks.new(cluster, disks_in_this_cluster)
      end.sort_by(&:total_disk_size_in_mb).reverse
    end
  end
end
