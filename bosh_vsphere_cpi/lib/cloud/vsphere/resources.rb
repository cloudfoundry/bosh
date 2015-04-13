require 'cloud/vsphere/resources/datacenter'

module VSphereCloud
  class Resources
    MEMORY_HEADROOM = 128
    DISK_HEADROOM = 1024
    STALE_TIMEOUT = 60
    BYTES_IN_MB = 1024 * 1024

    attr_reader :drs_rules

    def initialize(datacenter, config)
      @datacenter = datacenter
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
        if cluster.nil?
          raise Bosh::Clouds::CloudError, "Couldn't find cluster '#{cluster_name}'. Found #{@datacenter.clusters.values.map(&:name)}"
        end

        datastore = cluster.pick_persistent(disk_size_in_mb)
        datastore.allocate(disk_size_in_mb)
        datastore
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
        clusters = @datacenter.clusters.values
        persistent_disk_index = PersistentDiskIndex.new(clusters, existing_persistent_disks)

        scored_clusters = clusters.map do |cluster|
          persistent_disk_not_in_this_cluster = existing_persistent_disks.reject do |disk|
            persistent_disk_index.clusters_connected_to_disk(disk).include?(cluster)
          end

          score = Scorer.score(
            @config.logger,
            cluster,
            requested_memory_in_mb,
            requested_ephemeral_disk_size_in_mb,
            persistent_disk_not_in_this_cluster.map(&:size_in_mb)
          )

          [cluster, score]
        end

        acceptable_clusters = scored_clusters.select { |_, score| score > 0 }

        @logger.debug("Acceptable clusters: #{acceptable_clusters.inspect}")

        if acceptable_clusters.empty?
          total_persistent_size = existing_persistent_disks.map(&:size_in_mb).inject(0, :+)
          cluster_infos = clusters.map { |cluster| describe_cluster(cluster) }

          raise "Unable to allocate vm with #{requested_memory_in_mb}mb RAM, " +
              "#{requested_ephemeral_disk_size_in_mb / 1024}gb ephemeral disk, " +
              "and #{total_persistent_size / 1024}gb persistent disk from any cluster.\n#{cluster_infos.join(", ")}."
        end

        acceptable_clusters = acceptable_clusters.sort_by do |cluster, _score|
          persistent_disk_index.disks_connected_to_cluster(cluster).map(&:size_in_mb).inject(0, :+)
        end.reverse

        if acceptable_clusters.any? { |cluster, _| persistent_disk_index.disks_connected_to_cluster(cluster).any? }
          @logger.debug('Choosing cluster with the greatest available disk')
          selected_cluster, _ = acceptable_clusters.first
        else
          @logger.debug('Choosing cluster by weighted random')
          selected_cluster = Util.weighted_random(acceptable_clusters)
        end

        @logger.debug("Selected cluster '#{selected_cluster.name}'")

        selected_cluster.allocate(requested_memory_in_mb)
        selected_cluster
      end
    end

    def describe_cluster(cluster)
      "#{cluster.name} has #{cluster.free_memory}mb/" +
        "#{cluster.total_free_ephemeral_disk_in_mb / 1024}gb/" +
        "#{cluster.total_free_persistent_disk_in_mb / 1024}gb"
    end

    def pick_ephemeral_datastore(cluster, disk_size_in_mb)
      @lock.synchronize do
        datastore = cluster.pick_ephemeral(disk_size_in_mb)
        datastore.allocate(disk_size_in_mb)
        datastore
      end
    end

    def pick_persistent_datastore(cluster, disk_size_in_mb)
      @lock.synchronize do
        datastore = cluster.pick_persistent(disk_size_in_mb)
        datastore.allocate(disk_size_in_mb)
        datastore
      end
    end

    private

    attr_reader :config


    class PersistentDiskIndex
      def initialize(clusters, existing_persistent_disks)
        @clusters_to_disks = Hash[*clusters.map do |cluster|
            [cluster, existing_persistent_disks.select { |disk| cluster_includes_datastore?(cluster, disk.datastore) }]
          end.flatten(1)]

        @disks_to_clusters = Hash[*existing_persistent_disks.map do |disk|
            [disk, clusters.select { |cluster| cluster_includes_datastore?(cluster, disk.datastore) }]
          end.flatten(1)]
      end

      def cluster_includes_datastore?(cluster, datastore)
        cluster.persistent(datastore.name) != nil
      end

      def disks_connected_to_cluster(cluster)
        @clusters_to_disks[cluster]
      end

      def clusters_connected_to_disk(disk)
        @disks_to_clusters[disk]
      end
    end
  end
end
