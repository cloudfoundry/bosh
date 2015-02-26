require 'cloud/vsphere/resources/datacenter'

module VSphereCloud
  class Resources
    MEMORY_THRESHOLD = 128
    DISK_THRESHOLD = 1024
    STALE_TIMEOUT = 60
    BYTES_IN_MB = 1024 * 1024

    attr_reader :drs_rules

    def initialize(datacenter, cluster_locality, config)
      @datacenter = datacenter
      @cluster_locality = cluster_locality
      @config = config
      @logger = config.logger
      @last_update = 0
      @lock = Monitor.new
      @drs_rules = []
    end

    # Place the persistent datastore in the given datacenter and cluster with
    # the requested disk space.
    #
    # @param [String] cluster_name cluster name.
    # @param [Integer] disk_size_in_mb disk size in mb.
    # @return [Datastore?] datastore if it was placed succesfuly.
    def pick_persistent_datastore_in_cluster(cluster_name, disk_size_in_mb)
      @lock.synchronize do
        cluster = @datacenter.clusters[cluster_name]
        return nil if cluster.nil?

        pick_datastore(cluster, disk_size_in_mb)
      end
    end

    # Picks the persistent datastore with the requested disk space.
    #
    # @param [Disk] disk_size_in_mb disk size in mb.
    # @return [Datastore] datastore if it was placed succesfuly.
    def pick_persistent_datastore(disk)
      @lock.synchronize do
        place(0, 0, [disk])
      end
    end

    # Find a place for the requested resources.
    #
    # @param [Integer] memory requested memory.
    # @param [Integer] ephemeral requested ephemeral storage.
    # @param [Array<Resources::Disk>] persistent requested persistent storage.
    # @return [Array] an array/tuple of Cluster and Datastore if the resources
    #   were placed successfully, otherwise exception.
    def place(memory, ephemeral_size, persistent_disks)
      # calculate locality to prioritizing clusters that contain the most
      # persistent data.
      clusters_with_disks = @cluster_locality.clusters_ordered_by_disk_size(persistent_disks)

      scored_clusters = clusters_with_disks.map do |cluster|
        score = Scorer.new(@config, cluster, memory, ephemeral_size).score
        [cluster, score]
      end

      acceptable_clusters = scored_clusters.select { |_, score| score > 0 }

      raise "No available resources" if acceptable_clusters.empty?

      if acceptable_clusters.any? { |cluster, _| cluster.disks.any? }
        selected_cluster_with_disks, _ = acceptable_clusters.first
      else
        @logger.debug("Ignoring datastore locality as we could not find " +
          "any resources near disks: #{persistent_disks.inspect}")
        selected_cluster_with_disks = Util.weighted_random(acceptable_clusters)
      end

      selected_cluster = selected_cluster_with_disks.cluster
      datastore = selected_cluster.pick_ephemeral(ephemeral_size)
      # if datastore
      selected_cluster.allocate(memory)
      datastore.allocate(ephemeral_size)
      return [selected_cluster, datastore]
      # end
  end

    private

    attr_reader :config

    def pick_datastore(cluster, disk_space)
      datastore = cluster.pick_persistent(disk_space)
      return nil if datastore.nil?
      datastore.allocate(disk_space)
      datastore
    end
  end
end
