require 'cloud/vsphere/resources/datacenter'

module VSphereCloud
  class Resources
    MEMORY_THRESHOLD = 128
    DISK_THRESHOLD = 1024
    STALE_TIMEOUT = 60
    BYTES_IN_MB = 1024 * 1024

    attr_reader :drs_rules

    def initialize(config)
      @config = config
      @logger = config.logger
      @last_update = 0
      @lock = Monitor.new
      @drs_rules = []
    end

    # Returns the list of datacenters available for placement.
    #
    # Will lazily load them and reload the data when it's stale.
    #
    # @return [List<Resources::Datacenter>] datacenters.
    def datacenters
      @lock.synchronize do
        update if Time.now.to_i - @last_update > STALE_TIMEOUT
      end
      @datacenters
    end

    # Returns the persistent datastore for the requested context.
    #
    # @param [String] dc_name datacenter name.
    # @param [String] cluster_name cluster name.
    # @param [String] datastore_name datastore name.
    # @return [Resources::Datastore] persistent datastore.
    def persistent_datastore(dc_name, cluster_name, datastore_name)
      datacenter = datacenters[dc_name]
      return nil if datacenter.nil?
      cluster = datacenter.clusters[cluster_name]
      return nil if cluster.nil?
      cluster.persistent(datastore_name)
    end

    # Place the persistent datastore in the given datacenter and cluster with
    # the requested disk space.
    #
    # @param [String] dc_name datacenter name.
    # @param [String] cluster_name cluster name.
    # @param [Integer] disk_space disk space.
    # @return [Datastore?] datastore if it was placed succesfuly.
    def place_persistent_datastore(dc_name, cluster_name, disk_space)
      @lock.synchronize do
        datacenter = datacenters[dc_name]
        return nil if datacenter.nil?
        cluster = datacenter.clusters[cluster_name]
        return nil if cluster.nil?
        datastore = cluster.pick_persistent(disk_space)
        return nil if datastore.nil?
        datastore.allocate(disk_space)
        return datastore
      end
    end

    # Picks the persistent datastore with the requested disk space.
    #
    # @param [Integer] disk_space disk space.
    # @return [Datastore?] datastore if it was placed succesfuly.
    def pick_persistent_datastore(disk_size_in_mb)
      @lock.synchronize do
        cluster = pick_cluster(0, disk_size_in_mb, [])
        return nil if cluster.nil?
        datastore = cluster.pick_persistent(disk_size_in_mb)
        return nil if datastore.nil?
        datastore.allocate(disk_size_in_mb)
        return datastore
      end
    end

    # Find a place for the requested resources.
    #
    # @param [Integer] memory requested memory.
    # @param [Integer] ephemeral requested ephemeral storage.
    # @param [Array<Hash>] persistent requested persistent storage.
    # @return [Array] an array/tuple of Cluster and Datastore if the resources
    #   were placed successfully, otherwise exception.
    def place(memory, ephemeral, persistent)
      populate_resources(persistent)

      # calculate locality to prioritizing clusters that contain the most
      # persistent data.
      locality = cluster_locality(persistent)
      locality.sort! { |a, b| b[1] <=> a[1] }

      @lock.synchronize do
        locality.each do |cluster, _|
          persistent_sizes = persistent_sizes_for_cluster(cluster, persistent)

          scorer = Scorer.new(@config, cluster, memory, ephemeral, persistent_sizes)
          if scorer.score > 0
            datastore = cluster.pick_ephemeral(ephemeral)
            if datastore
              cluster.allocate(memory)
              datastore.allocate(ephemeral)
              return [cluster, datastore]
            end
          end
        end

        unless locality.empty?
          @logger.debug("Ignoring datastore locality as we could not find " +
                          "any resources near disks: #{persistent.inspect}")
        end

        cluster = pick_cluster(memory, ephemeral, persistent)

        datastore = cluster.pick_ephemeral(ephemeral)

        if datastore
          cluster.allocate(memory)
          datastore.allocate(ephemeral)
          return [cluster, datastore]
        end

        raise 'No available resources'
      end
    end

    def pick_cluster(memory, disk_size_in_mb, existing_persistent_disk_cids)
      weighted_clusters = []

      datacenter = datacenters.first.last
      datacenter.clusters.each_value do |cluster|
        persistent_sizes = persistent_sizes_for_cluster(cluster, existing_persistent_disk_cids)
        scorer = Scorer.new(@config, cluster, memory, disk_size_in_mb, persistent_sizes)
        score = scorer.score
        @logger.debug("Score: #{cluster.name}: #{score}")
        weighted_clusters << [cluster, score] if score > 0
      end

      raise 'No available resources' if weighted_clusters.empty?

      Util.weighted_random(weighted_clusters)
    end

    private

    attr_reader :config

    # Updates the resource models from vSphere.
    # @return [void]
    def update
      #datacenter_config = config.vcenter_datacenter
      datacenter = Datacenter.new(config)
      @datacenters = { datacenter.name => datacenter }
      @last_update = Time.now.to_i
    end

    # Calculates the cluster locality for the provided persistent disks.
    #
    # @param [Array<Hash>] disks persistent disk specs.
    # @return [Hash<String, Integer>] hash of cluster names to amount of
    #   persistent disk space is currently allocated on them.
    def cluster_locality(disks)
      locality = {}
      disks.each do |disk|
        cluster = disk[:cluster]
        unless cluster.nil?
          locality[cluster] ||= 0
          locality[cluster] += disk[:size]
        end
      end
      locality.to_a
    end

    # Fill in the resource models on the provided persistent disk specs.
    # @param [Array<Hash>] disks persistent disk specs.
    # @return [void]
    def populate_resources(disks)
      disks.each do |disk|
        unless disk[:ds_name].nil?
          resources = persistent_datastore_resources(disk[:dc_name],
                                                     disk[:ds_name])
          if resources
            disk[:datacenter], disk[:cluster], disk[:datastore] = resources
          end
        end
      end
    end

    # Find the resource models for a given datacenter and datastore name.
    #
    # Has to traverse the resource hierarchy to find the cluster, then returns
    # all of the resources.
    #
    # @param [String] dc_name datacenter name.
    # @param [String] ds_name datastore name.
    # @return [Array] array/tuple of Datacenter, Cluster, and Datastore.
    def persistent_datastore_resources(dc_name, ds_name)
      datacenter = datacenters[dc_name]
      return nil if datacenter.nil?
      datacenter.clusters.each_value do |cluster|
        datastore = cluster.persistent(ds_name)
        return [datacenter, cluster, datastore] unless datastore.nil?
      end
      nil
    end

    # Filters out all of the persistent disk specs that were already allocated
    # in the cluster.
    #
    # @param [Resources::Cluster] cluster specified cluster.
    # @param [Array<Hash>] disks disk specs.
    # @return [Array<Hash>] filtered out disk specs.
    def persistent_sizes_for_cluster(cluster, disks)
      disks.select { |disk| disk[:cluster] != cluster }.
        collect { |disk| disk[:size] }
    end
  end
end
