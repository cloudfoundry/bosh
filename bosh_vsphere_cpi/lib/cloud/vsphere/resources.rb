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

    # Find a cluster for a vm with the requested memory and ephemeral storage, attempting
    # to allocate it near existing persistent disks.
    #
    # @param [Integer] requested_memory_in_mb requested memory.
    # @param [Integer] requested_ephemeral_disk_size_in_mb requested ephemeral storage.
    # @param [Array<Resources::Disk>] existing_persistent_disks existing persistent disks, if any.
    # @return [Cluster] selected cluster if the resources were placed successfully, otherwise raises.
    def pick_cluster_for_vm(requested_memory_in_mb, requested_ephemeral_disk_size_in_mb, existing_persistent_disks)
      @lock.synchronize do
        # calculate locality to prioritizing clusters that contain the most persistent data.
        clusters_with_disks = @cluster_locality.clusters_ordered_by_disk_size(existing_persistent_disks)

        scored_clusters = clusters_with_disks.map do |cluster|
          other_clusters = clusters_with_disks.select { |other_cluster| cluster != other_cluster }
          persistent_disk_sizes = cluster.disk_sizes_in_other_clusters(other_clusters)

          score = Scorer.new(
            @config, cluster.cluster,
            requested_memory_in_mb,
            requested_ephemeral_disk_size_in_mb,
            persistent_disk_sizes
          ).score

          [cluster, score]
        end

        acceptable_clusters = scored_clusters.select { |_, score| score > 0 }

        @logger.debug("Acceptable clusters: #{acceptable_clusters.inspect}")

        raise 'No available resources' if acceptable_clusters.empty?

        if acceptable_clusters.any? { |cluster, _| cluster.disks.any? }
          @logger.debug('Choosing cluster with the most disk size')
          cluster_with_disks, _ = acceptable_clusters.first
          selected_cluster = cluster_with_disks.cluster
        else
          @logger.debug('Choosing cluster by weighted random')
          clusters_with_scores = acceptable_clusters.map { |clusters_with_disks, score| [clusters_with_disks.cluster, score] }
          selected_cluster = Util.weighted_random(clusters_with_scores)
        end

        @logger.debug("Selected cluster '#{selected_cluster.name}'")

        selected_cluster.allocate(requested_memory_in_mb)
        selected_cluster
      end
    end

    def pick_ephemeral_datastore(cluster, disk_size_in_mb)
      @lock.synchronize do
        datastore = cluster.pick_ephemeral(disk_size_in_mb)
        if datastore.nil?
          raise Bosh::Clouds::NoDiskSpace.new(
            "Not enough ephemeral disk space (#{disk_size_in_mb}MB) in cluster #{cluster.name}")
        end

        datastore.allocate(disk_size_in_mb)
        datastore
      end
    end

    def pick_persistent_datastore(cluster, disk_size_in_mb)
      @lock.synchronize do
        datastore = cluster.pick_persistent(disk_size_in_mb)
        if datastore.nil?
          raise Bosh::Clouds::NoDiskSpace.new(
            "Not enough persistent disk space (#{disk_size_in_mb}MB) in cluster #{cluster.name}")
        end

        datastore.allocate(disk_size_in_mb)
        datastore
      end
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
