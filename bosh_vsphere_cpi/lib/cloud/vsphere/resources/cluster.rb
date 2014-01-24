module VSphereCloud
  class Resources
    class Cluster
      include VimSdk

      PROPERTIES = %w(name datastore resourcePool host)
      HOST_PROPERTIES = %w(hardware.memorySize runtime.inMaintenanceMode)
      HOST_COUNTERS = %w(mem.usage.average)

      # @!attribute mob
      #   @return [Vim::ClusterComputeResource] cluster vSphere MOB.
      attr_reader :mob

      # @!attribute datacenter
      #   @return [Datacenter] parent datacenter.
      #attr_accessor :datacenter

      # @!attribute resource_pool
      #   @return [ResourcePool] resource pool.
      attr_reader :resource_pool

      # @!attribute ephemeral_datastores
      #   @return [Hash<String, Datastore>] ephemeral datastores.
      attr_reader :ephemeral_datastores

      # @!attribute persistent_datastores
      #   @return [Hash<String, Datastore>] persistent datastores.
      attr_reader :persistent_datastores

      # @!attribute shared_datastores
      #   @return [Hash<String, Datastore>] shared datastores.
      attr_reader :shared_datastores

      # @!attribute synced_free_memory
      #   @return [Integer] cached memory utilization in MB.
      attr_accessor :synced_free_memory

      # @!attribute allocated_after_sync
      #   @return [Integer] memory allocated since utilization sync in MB.
      attr_accessor :allocated_after_sync

      # Creates a new Cluster resource from the specified datacenter, cluster
      # configuration, and prefetched properties.
      #
      # @param [CloudConfig] VSphereCloud::Config
      # @param [ClusterConfig] config cluster configuration as specified by the
      #   operator.
      # @param [Hash] properties prefetched vSphere properties for the cluster.
      def initialize(cloud_config, cluster_config, properties)
        @logger = cloud_config.logger
        @client = cloud_config.client
        @properties = properties

        @config = cluster_config
        @cloud_config = cloud_config
        @mob = properties['obj']
        @resource_pool = ResourcePool.new(cloud_config, cluster_config, properties["resourcePool"])

        @allocated_after_sync = 0
        @ephemeral_datastores = {}
        @persistent_datastores = {}
        @shared_datastores = {}

        setup_datastores

        # Have to use separate mechanisms for fetching utilization depending on
        # whether we're using resource pools or raw clusters.
        if @config.resource_pool.nil?
          fetch_cluster_utilization(properties['host'])
        else
          fetch_resource_pool_utilization
        end
      end

      # Returns the persistent datastore by name. This could be either from the
      # exclusive or shared datastore pools.
      #
      # @param [String] datastore_name name of the datastore.
      # @return [Datastore, nil] the requested persistent datastore.
      def persistent(datastore_name)
        @persistent_datastores[datastore_name] ||
          @shared_datastores[datastore_name]
      end

      # @return [Integer] amount of free memory in the cluster
      def free_memory
        @synced_free_memory -
          (@allocated_after_sync * cloud_config.mem_overcommit).to_i
      end

      # Marks the memory reservation against the cached utilization data.
      #
      # @param [Integer] memory size of memory reservation.
      # @return [void]
      def allocate(memory)
        @allocated_after_sync += memory
      end


      # Picks the best datastore for the specified persistent disk.
      #
      # @param [Integer] size persistent disk size.
      # @return [Datastore, nil] best datastore if available for the requested
      #   size.
      def pick_persistent(size)
        pick_store(size, :persistent)
      end

      # Picks the best datastore for the specified ephemeral disk.
      #
      # @param [Integer] size ephemeral disk size.
      # @return [Datastore, nil] best datastore if available for the requested
      #   size.
      def pick_ephemeral(size)
        pick_store(size, :ephemeral)
      end

      # @return [String] cluster name.
      def name
        config.name
      end

      # @return [String] debug cluster information.
      def inspect
        "<Cluster: #{mob} / #{config.name}>"
      end

      private

      attr_reader :cloud_config, :config, :client, :properties, :logger

      def setup_datastores
        datastores_properties = client.get_properties(properties['datastore'], Vim::Datastore, Datastore::PROPERTIES)

        datastores_properties.each_value do |datastore_properties|
          name = datastore_properties["name"]

          ephemeral = !!(name =~ cloud_config.datacenter_datastore_pattern)
          persistent = !!(name =~ cloud_config.datacenter_persistent_datastore_pattern)

          if ephemeral && persistent && !cloud_config.datacenter_allow_mixed_datastores
            raise "Datastore patterns are not mutually exclusive: #{name}"
          end

          if ephemeral || persistent
            place_datastore(datastore_properties, ephemeral, persistent)
          end
        end

        logger.debug(
          "Datastores - ephemeral: #{@ephemeral_datastores.keys.inspect}, " +
            "persistent: #{@persistent_datastores.keys.inspect}, " +
            "shared: #{@shared_datastores.keys.inspect}.")
      end

      def place_datastore(datastore_properties, ephemeral, persistent)
        datastore = Datastore.new(datastore_properties)
        if ephemeral && persistent
          @shared_datastores[datastore.name] = datastore
        elsif ephemeral
          @ephemeral_datastores[datastore.name] = datastore
        else
          @persistent_datastores[datastore.name] = datastore
        end
      end

      # Picks the best datastore for the specified disk size and type.
      #
      # First the exclusive datastore pool is used. If it's empty or doesn't
      # have enough capacity then the shared pool will be used.
      #
      # @param [Integer] size disk size.
      # @param [Symbol] type disk type.
      # @return [Datastore, nil] best datastore if available for the requested
      #   size.
      def pick_store(size, type)
        weighted_datastores = []
        datastores =
          type == :persistent ? @persistent_datastores : @ephemeral_datastores
        datastores.each_value do |datastore|
          if datastore.free_space - size >= DISK_THRESHOLD
            weighted_datastores << [datastore, datastore.free_space]
          end
        end

        if weighted_datastores.empty?
          @shared_datastores.each_value do |datastore|
            if datastore.free_space - size >= DISK_THRESHOLD
              weighted_datastores << [datastore, datastore.free_space]
            end
          end
        end

        Util.weighted_random(weighted_datastores)
      end

      # Fetches the raw cluster utilization from vSphere.
      #
      # First filter out any hosts that are in maintenance mode. Then aggregate
      # individual host capacity and its utilization using the performance
      # manager.
      #
      # @param [Array<Vim::HostSystem>] cluster_host_systems cluster hosts.
      # @return [void]
      def fetch_cluster_utilization(cluster_host_systems)
        hosts_properties = @client.get_properties(
          cluster_host_systems, Vim::HostSystem, HOST_PROPERTIES, ensure_all: true)
        active_host_mobs = select_active_host_mobs(hosts_properties)

        @synced_free_memory = 0
        return if active_host_mobs.empty?

        cluster_free_memory = 0

        counters = @client.get_perf_counters(active_host_mobs, HOST_COUNTERS, max_sample: 5)
        counters.each do |host_mob, counter|
          host_properties = hosts_properties[host_mob]
          total_memory = host_properties["hardware.memorySize"].to_i
          percent_used = Util.average_csv(counter["mem.usage.average"]) / 10000
          free_memory = ((1.0 - percent_used) * total_memory).to_i

          cluster_free_memory += free_memory
        end

        @synced_free_memory = cluster_free_memory / BYTES_IN_MB
      end

      # Filters out the hosts that are in maintenance mode.
      #
      # @param [Hash] host_properties host properties that already fetched
      #   inMaintenanceMode from vSphere.
      # @return [Array<Vim::HostSystem>] list of hosts that are active
      def select_active_host_mobs(host_properties)
        host_properties.values.
          select { |p| p['runtime.inMaintenanceMode'] != 'true' }.
          collect { |p| p['obj'] }
      end

      # Fetches the resource pool utilization from vSphere.
      #
      # We can only rely on the vSphere data if the resource pool is healthy.
      # Otherwise we mark the resources as unavailable.
      #
      # Unfortunately this method does not work for the root resource pool,
      # so we can't use it for the raw clusters.
      #
      # @return [void]
      def fetch_resource_pool_utilization
        properties = @client.get_properties(resource_pool.mob, Vim::ResourcePool, 'summary')
        raise "Failed to get utilization for resource pool #{resource_pool}" if properties.nil?

        runtime_info = properties["summary"].runtime

        if runtime_info.overall_status == "green"
          memory = runtime_info.memory
          @synced_free_memory = (memory.max_usage - memory.overall_usage) / BYTES_IN_MB
        else
          logger.warn("Ignoring cluster: #{config.name} resource_pool: " +
                         "#{resource_pool.mob} as its state is " +
                         "unreliable: #{runtime_info.overall_status}")
          @synced_free_memory = 0
        end
      end
    end
  end
end
