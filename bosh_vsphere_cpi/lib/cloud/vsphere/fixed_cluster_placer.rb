module VSphereCloud
  class FixedClusterPlacer
    attr_reader :drs_rules

    def initialize(cluster, drs_rules)
      @cluster = cluster
      @drs_rules = drs_rules
    end

    def pick_cluster_for_vm(memory, ephemeral, persistent)
      @cluster.allocate(memory)
      @cluster
    end

    def pick_ephemeral_datastore(cluster, disk_size_in_mb)
      datastore = cluster.pick_ephemeral(disk_size_in_mb)

      if datastore.nil?
        raise Bosh::Clouds::NoDiskSpace.new(
          "Not enough ephemeral disk space (#{disk_size_in_mb}MB) in cluster #{cluster.name}")
      end

      datastore.allocate(disk_size_in_mb)
      datastore
    end

    def pick_persistent_datastore(_, _)
      raise NotImplementedError
    end
  end
end
