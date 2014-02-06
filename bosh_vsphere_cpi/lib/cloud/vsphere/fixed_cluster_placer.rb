module VSphereCloud
  class FixedClusterPlacer
    def initialize(cluster)
      @cluster = cluster
    end

    def place(memory, ephemeral, persistent)
      datastore = @cluster.pick_ephemeral(ephemeral)
      if datastore
        @cluster.allocate(memory)
        datastore.allocate(ephemeral)
        return [@cluster, datastore]
      end
      raise "No available resources"
    end
  end
end
