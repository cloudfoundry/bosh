module VSphereCloud
  class FixedClusterPlacer
    attr_reader :drs_rules

    def initialize(cluster, drs_rules)
      @cluster = cluster
      @drs_rules = drs_rules
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
