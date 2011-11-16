module VSphereCloud

  class Resources
    include VimSdk

    MEMORY_THRESHOLD = 128
    DISK_THRESHOLD = 512

    class Datacenter
      attr_accessor :mob
      attr_accessor :name
      attr_accessor :clusters
      attr_accessor :vm_folder
      attr_accessor :vm_folder_name
      attr_accessor :template_folder
      attr_accessor :template_folder_name
      attr_accessor :disk_path
      attr_accessor :datastore_pattern
      attr_accessor :persistent_datastore_pattern
      attr_accessor :allow_mixed_datastores
      attr_accessor :spec

      def inspect
        "<Datacenter: #{@mob} / #{@name}>"
      end
    end

    class Datastore
      attr_accessor :mob
      attr_accessor :name
      attr_accessor :total_space
      attr_accessor :free_space
      attr_accessor :unaccounted_space

      def real_free_space
        @free_space - @unaccounted_space
      end

      def inspect
        "<Datastore: #{@mob} / #{@name}>"
      end
    end

    class Cluster
      attr_accessor :mob
      attr_accessor :name
      attr_accessor :datacenter
      attr_accessor :resource_pool
      attr_accessor :datastores
      attr_accessor :persistent_datastores
      attr_accessor :idle_cpu
      attr_accessor :total_memory
      attr_accessor :free_memory
      attr_accessor :unaccounted_memory
      attr_accessor :mem_over_commit

      def real_free_memory
        @free_memory - @unaccounted_memory * @mem_over_commit
      end

      def inspect
        "<Cluster: #{@mob} / #{@name}>"
      end
    end

    def initialize(client, vcenter, mem_over_commit = 1.0)
      @client           = client
      @vcenter          = vcenter
      @datacenters      = {}
      @timestamp        = 0
      @lock             = Monitor.new
      @logger           = Bosh::Director::Config.logger
      @mem_over_commit  = mem_over_commit
    end

    def fetch_datacenters
      datacenters      = @client.get_managed_objects(Vim::Datacenter)
      properties       = @client.get_properties(datacenters, Vim::Datacenter, ["name"])
      datacenter_specs = {}

      @vcenter["datacenters"].each { |spec| datacenter_specs[spec["name"]] = spec }
      properties.delete_if { |_, datacenter_properties| !datacenter_specs.has_key?(datacenter_properties["name"]) }

      datacenters = {}
      properties.each_value do |datacenter_properties|
        datacenter                      = Datacenter.new
        datacenter.mob                  = datacenter_properties[:obj]
        datacenter.name                 = datacenter_properties["name"]

        @logger.debug("Found datacenter: #{datacenter.name} @ #{datacenter.mob}")

        datacenter.spec                 = datacenter_specs[datacenter.name]
        datacenter.vm_folder_name       = datacenter.spec["vm_folder"]
        datacenter.template_folder_name = datacenter.spec["template_folder"]
        datacenter.template_folder      = @client.find_by_inventory_path([datacenter.name, "vm",
                                                                          datacenter.spec["template_folder"]])
        datacenter.vm_folder            = @client.find_by_inventory_path([datacenter.name, "vm",
                                                                          datacenter.spec["vm_folder"]])
        datacenter.disk_path            = datacenter.spec["disk_path"]
        datacenter.datastore_pattern    = Regexp.new(datacenter.spec["datastore_pattern"])
        raise "Missing persistent_datastore_pattern in director config" if datacenter.spec["persistent_datastore_pattern"].nil?
        datacenter.persistent_datastore_pattern = Regexp.new(datacenter.spec["persistent_datastore_pattern"])

        datacenter.allow_mixed_datastores = !!datacenter.spec["allow_mixed_datastores"]

        datacenter.clusters             = fetch_clusters(datacenter)
        datacenters[datacenter.name]    = datacenter
      end
      datacenters
    end

    # Allow clusters to be specified as
    #
    # clusters:                      clusters:
    #   - CLUSTER1                     - CLUSTER1:
    #   - CLUSTER2       OR                resource_pool: SOME_RP
    #   - CLUSTER3                     - CLUSTER2
    #                                  - CLUSTER3
    def get_cluster_spec(clusters)
      cluster_spec = {}
      clusters.each do |cluster|
        case cluster
        when String
          cluster_spec[cluster] = nil
        when Hash
          cluster_spec[cluster.keys.first] = cluster[cluster.keys.first]["resource_pool"]
        else
          raise "Bad cluster information in datacenter spec #{clusters.pretty_inspect}"
        end
      end
      cluster_spec
    end

    def fetch_clusters(datacenter)
      datacenter_spec = datacenter.spec
      cluster_mobs    = @client.get_managed_objects(Vim::ClusterComputeResource, :root => datacenter.mob)
      properties      = @client.get_properties(cluster_mobs, Vim::ClusterComputeResource,
                                               ["name", "datastore", "resourcePool", "host"], :ensure_all => true)

      cluster_spec = get_cluster_spec(datacenter_spec["clusters"])
      cluster_names = Set.new(cluster_spec.keys)
      properties.delete_if { |_, cluster_properties| !cluster_names.include?(cluster_properties["name"]) }

      clusters = []
      properties.each_value do |cluster_properties|
        requested_resource_pool = cluster_spec[cluster_properties["name"]]
        cluster_resource_pool = fetch_resource_pool(requested_resource_pool, cluster_properties)
        next if cluster_resource_pool.nil?

        cluster                    = Cluster.new
        cluster.mem_over_commit    = @mem_over_commit
        cluster.mob                = cluster_properties[:obj]
        cluster.name               = cluster_properties["name"]

        @logger.debug("Found cluster: #{cluster.name} @ #{cluster.mob}")

        cluster.resource_pool      = cluster_resource_pool
        cluster.datacenter         = datacenter
        cluster.datastores         = fetch_datastores(datacenter, cluster_properties["datastore"],
                                                      datacenter.datastore_pattern)
        cluster.persistent_datastores = fetch_datastores(datacenter, cluster_properties["datastore"],
                                                         datacenter.persistent_datastore_pattern)

        # make sure datastores and persistent_datastores are mutually exclusive
        datastore_names = cluster.datastores.map { |ds|
          ds.name
        }
        persistent_datastore_names = cluster.persistent_datastores.map { |ds|
          ds.name
        }
        if (datastore_names & persistent_datastore_names).length != 0 && !datacenter.allow_mixed_datastores
          raise("datastore patterns are not mutually exclusive non-persistent are " +
                "#{datastore_names.pretty_inspect}\n persistent are #{persistent_datastore_names.pretty_inspect}, " +
                "please use allow_mixed_datastores director configuration parameter to allow this")
        end
        @logger.debug("non-persistent datastores are " + "#{datastore_names.pretty_inspect}\n " +
                      "persistent datastores are #{persistent_datastore_names.pretty_inspect}")

        if requested_resource_pool.nil?
          # Ideally we would just get the utilization for the root resource pool, but
          # VC does not really have "real time" updates for utilization so for
          # now we work around that by querying the cluster hosts directly.
          fetch_cluster_utilization(cluster, cluster_properties["host"])
        else
          fetch_resource_pool_utilization(requested_resource_pool, cluster)
        end

        clusters << cluster
      end
      clusters
    end

    def fetch_resource_pool(requested_resource_pool, cluster_properties)
      root_resource_pool = cluster_properties["resourcePool"]

      return root_resource_pool if requested_resource_pool.nil?

      # Get list of resource pools under this cluster
      properties = @client.get_properties(root_resource_pool, Vim::ResourcePool, ["resourcePool"])
      if properties && properties["resourcePool"] && properties["resourcePool"].size != 0

        # Get the name of each resource pool under this cluster
        child_properties = @client.get_properties(properties["resourcePool"], Vim::ResourcePool, ["name"])
        if child_properties
          child_properties.each_value do | resource_pool |
            if resource_pool["name"] == requested_resource_pool
              @logger.info("Found requested resource pool #{requested_resource_pool} under cluster #{cluster_properties["name"]}")
              return resource_pool[:obj]
            end
          end
        end
      end
      @logger.info("Could not find requested resource pool #{requested_resource_pool} under cluster #{cluster_properties["name"]}")
      nil
    end

    def fetch_datastores(datacenter, datastore_mobs, match_pattern)
      properties = @client.get_properties(datastore_mobs, Vim::Datastore,
                                          ["summary.freeSpace", "summary.capacity", "name"])
      properties.delete_if { |_, datastore_properties| datastore_properties["name"] !~ match_pattern }

      datastores = []
      properties.each_value do |datastore_properties|
        datastore                   = Datastore.new
        datastore.mob               = datastore_properties[:obj]
        datastore.name              = datastore_properties["name"]

        @logger.debug("Found datastore: #{datastore.name} @ #{datastore.mob}")

        datastore.free_space        = datastore_properties["summary.freeSpace"].to_i / (1024 * 1024)
        datastore.total_space       = datastore_properties["summary.capacity"].to_i / (1024 * 1024)
        datastore.unaccounted_space = 0
        datastores << datastore
      end
      datastores
    end

    def fetch_cluster_utilization(cluster, host_mobs)
      properties = @client.get_properties(host_mobs, Vim::HostSystem,
                                          ["hardware.memorySize", "runtime.inMaintenanceMode"], :ensure_all => true)
      properties.delete_if { |_, host_properties| host_properties["runtime.inMaintenanceMode"] == "true" }

      samples       = 0
      total_memory  = 0
      free_memory   = 0
      cpu_usage     = 0

      perf_counters = @client.get_perf_counters(host_mobs, ["cpu.usage.average", "mem.usage.average"], :max_sample => 5)
      perf_counters.each do |host_mob, perf_counter|
        host_properties          = properties[host_mob]
        next if host_properties.nil?
        host_total_memory        = host_properties["hardware.memorySize"].to_i
        host_percent_memory_used = average_csv(perf_counter["mem.usage.average"]) / 10000
        host_free_memory         = (1.0 - host_percent_memory_used) * host_total_memory

        samples                  += 1
        total_memory             += host_total_memory
        free_memory              += host_free_memory.to_i
        cpu_usage                += average_csv(perf_counter["cpu.usage.average"]) / 100
      end

      cluster.idle_cpu     = (100 - cpu_usage / samples) / 100
      cluster.total_memory = total_memory/(1024 * 1024)
      cluster.free_memory  = free_memory/(1024 * 1024)
      cluster.unaccounted_memory = 0
    end

    def fetch_resource_pool_utilization(resource_pool, cluster)
      properties = @client.get_properties(cluster.resource_pool, Vim::ResourcePool, ["summary"])
      raise "Failed to get utilization for resource pool #{resource_pool}" if properties.nil?

      if properties["summary"].runtime.overall_status == "green"
        runtime_info = properties["summary"].runtime
        cluster.idle_cpu = ((runtime_info.cpu.max_usage - runtime_info.cpu.overall_usage) * 1.0)/runtime_info.cpu.max_usage
        cluster.total_memory = (runtime_info.memory.reservation_used + runtime_info.memory.unreserved_for_vm)/(1024 * 1024)
        cluster.free_memory = [runtime_info.memory.unreserved_for_vm, runtime_info.memory.max_usage - runtime_info.memory.overall_usage].min/(1024 * 1024)
        cluster.unaccounted_memory = 0
      else
        # resource pool is in an unreliable state
        cluster.idle_cpu = 0
        cluster.total_memory = 0
        cluster.free_memory = 0
        cluster.unaccounted_memory = 0
      end
    end

    def average_csv(csv)
      values = csv.split(",")
      result = 0
      values.each { |v| result += v.to_f }
      result / values.size
    end

    def datacenters
      @lock.synchronize do
        if Time.now.to_i - @timestamp > 60
          @datacenters = fetch_datacenters
          @timestamp = Time.now.to_i
        end
      end
      @datacenters
    end

    def filter_used_resources(memory, vm_disk_size, persistent_disks_size, cluster_affinity)
      resources = []
      datacenters.each_value do |datacenter|
        datacenter.clusters.each do |cluster|
          next unless cluster_affinity.nil? || cluster.mob == cluster_affinity.mob
          next unless cluster.real_free_memory - memory > MEMORY_THRESHOLD
          next if pick_datastore(cluster.persistent_datastores, persistent_disks_size).nil?
          next if (datastore = pick_datastore(cluster.datastores, vm_disk_size)).nil?
          resources << [cluster, datastore]
        end
      end
      resources
    end

    def get_cluster(dc_name, cluster_name)
      datacenter = datacenters[dc_name]
      return nil if datacenter.nil?

      cluster = nil
      datacenter.clusters.each do |c|
        if c.name == cluster_name
          cluster = c
          break
        end
      end
      cluster
    end

    def validate_persistent_datastore(dc_name, datastore_name)
      datacenter = datacenters[dc_name]
      raise "Invalid datacenter #{dc_name} #{datacenters.pretty_inspect}" if datacenter.nil?

      return datastore_name =~ datacenter.persistent_datastore_pattern
    end

    def get_persistent_datastore(dc_name, cluster_name, persistent_datastore_name)
      cluster = get_cluster(dc_name, cluster_name)
      return nil if cluster.nil?

      datastore = nil
      cluster.persistent_datastores.each { |ds|
        if ds.name == persistent_datastore_name
          datastore = ds
          break
        end
      }
      datastore
    end

    def pick_datastore(datastores, disk_space)
      selected_datastores = {}
      datastores.each { |ds|
        if ds.real_free_space - disk_space > DISK_THRESHOLD
          selected_datastores[ds] = score_datastore(ds, disk_space)
        end
      }
      return nil if selected_datastores.empty?
      pick_random_with_score(selected_datastores)
    end

    def get_datastore_cluster(datacenter, datastore)
      datacenter = datacenters[datacenter]
      if !datacenter.nil?
        datacenter.clusters.each do |c|
          c.persistent_datastores.select do |ds|
            yield c if ds.name == datastore
          end
        end
      end
    end

    def find_persistent_datastore(dc_name, cluster_name, disk_space)
      cluster = get_cluster(dc_name, cluster_name)
      return nil if cluster.nil?

      chosen_datastore = nil
      @lock.synchronize do
        chosen_datastore = pick_datastore(cluster.persistent_datastores, disk_space)
        break if chosen_datastore.nil?

        chosen_datastore.unaccounted_space += disk_space
      end
      chosen_datastore
    end

    def find_resources(memory, disk_size, persistent_disks_size, cluster_affinity)
      cluster = nil
      datastore = nil

      # account for swap
      disk_size += memory

      @lock.synchronize do
        resources = filter_used_resources(memory, disk_size, persistent_disks_size, cluster_affinity)
        break if resources.empty?

        scored_resources = {}
        resources.each do |resource|
          cluster, datastore = resource
          scored_resources[resource] = score_resource(cluster, datastore, memory, disk_size)
        end

        scored_resources = scored_resources.sort_by { |resource| 1 - resource.last }
        scored_resources = scored_resources[0..2]

        scored_resources.each do |resource, score|
          cluster, datastore = resource
          @logger.debug("Cluster: #{cluster.inspect} Datastore: #{datastore.inspect} score: #{score}")
        end

        cluster, datastore = pick_random_with_score(scored_resources)

        @logger.debug("Picked: #{cluster.inspect} / #{datastore.inspect}")

        cluster.unaccounted_memory += memory
        datastore.unaccounted_space += disk_size
      end

      return [] if cluster.nil?
      [cluster, datastore]
    end

    def get_resources(memory_size=1, disks=[])
      # Sort out the persistent and non persistent disks
      non_persistent_disks_size = 0
      persistent_disks = {}
      persistent_disks_size = 0
      disks.each do |disk|
        if disk["persistent"]
          if !disk["datastore"].nil?
            # sanity check the persistent disks
            raise "Invalid persistent disk #{disk.pretty_inspect}" unless validate_persistent_datastore(disk["datacenter"], disk["datastore"])

            # sort the persistent disks into clusters they belong to
            get_datastore_cluster(disk["datacenter"], disk["datastore"]) { |cluster|
              persistent_disks[cluster] ||= 0
              persistent_disks[cluster] += disk["size"]
            }
          end
          persistent_disks_size += disk["size"]
        else
          non_persistent_disks_size += disk["size"]
        end
      end
      non_persistent_disks_size = 1 if non_persistent_disks_size == 0
      persistent_disks_size = 1 if persistent_disks_size == 0

      if !persistent_disks.empty?
        # Sort clusters by largest persistent disk footprint
        persistent_disks_by_size = persistent_disks.sort { |a, b| b[1] <=> a [1] }

        # Search for resources near the desired cluster
        persistent_disks_by_size.each do |cluster, size|
          resources = find_resources(memory_size, non_persistent_disks_size, persistent_disks_size - size, cluster)
          return resources unless resources.empty?
        end
        @logger.info("Ignoring datastore locality as we could not find any resources near persistent disks" +
                     "#{persistent_disks.pretty_inspect}")
      end

      resources = find_resources(memory_size, non_persistent_disks_size, persistent_disks_size, nil)
      raise "No available resources" if resources.empty?
      resources
    end

    def score_datastore(datastore, disk)
      percent_of_free_disk = 1 - (disk.to_f / datastore.real_free_space)
      percent_of_total_disk = 1 - (disk.to_f / datastore.total_space)
      percent_of_free_disk * 0.67 + percent_of_total_disk * 0.33
    end

    def score_resource(cluster, datastore, memory, disk)
      percent_of_free_mem = 1 - (memory.to_f / cluster.real_free_memory)
      percent_of_total_mem = 1 - (memory.to_f / cluster.total_memory)
      percent_free_mem_left = (cluster.real_free_memory.to_f - memory) / cluster.total_memory
      memory_score = percent_of_free_mem * 0.5 + percent_of_total_mem * 0.25 + percent_free_mem_left * 0.25

      cpu_score = cluster.idle_cpu
      disk_score = score_datastore(datastore, disk)
      memory_score * 0.5 + cpu_score * 0.25 + disk_score * 0.25
    end

    def pick_random_with_score(elements)
      score_sum = 0
      elements.each { |element| score_sum += element[1] }

      random_score = rand * score_sum
      base_score = 0

      elements.each do |element|
        score = element[1]
        return element[0] if base_score + score > random_score
        base_score += score
      end

      # fall through
      elements.last[0]
    end

  end

end
