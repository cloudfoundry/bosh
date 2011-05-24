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

      def real_free_memory
        @free_memory - @unaccounted_memory
      end

      def inspect
        "<Cluster: #{@mob} / #{@name}>"
      end
    end

    def initialize(client, vcenter)
      @client      = client
      @vcenter     = vcenter
      @datacenters = {}
      @timestamp   = 0
      @lock        = Monitor.new
      @logger      = Bosh::Director::Config.logger
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

    def fetch_clusters(datacenter)
      datacenter_spec = datacenter.spec
      cluster_mobs    = @client.get_managed_objects(Vim::ClusterComputeResource, :root => datacenter.mob)
      properties      = @client.get_properties(cluster_mobs, Vim::ClusterComputeResource,
                                               ["name", "datastore", "resourcePool", "host"], :ensure_all => true)

      cluster_names   = Set.new(datacenter_spec["clusters"])
      properties.delete_if { |_, cluster_properties| !cluster_names.include?(cluster_properties["name"]) }

      clusters = []
      properties.each_value do |cluster_properties|
        cluster                    = Cluster.new
        cluster.mob                = cluster_properties[:obj]
        cluster.name               = cluster_properties["name"]

        @logger.debug("Found cluster: #{cluster.name} @ #{cluster.mob}")

        cluster.resource_pool      = cluster_properties["resourcePool"]
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
        fetch_cluster_utilization(cluster, cluster_properties["host"])

        clusters << cluster
      end
      clusters
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

    def filter_used_resources(disk_space, memory)
      resources = []
      datacenters.each_value do |datacenter|
        datacenter.clusters.each do |cluster|
          has_memory = cluster.real_free_memory - memory > MEMORY_THRESHOLD
          if has_memory
            datastore = cluster.datastores.max_by { |datastore| datastore.real_free_space }
            has_disk = datastore.real_free_space - disk_space > DISK_THRESHOLD
            resources << [cluster, datastore] if has_disk
          end
        end
      end

      raise "No available resources" if resources.empty?
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

    def pick_datastore(cluster, disk_space, persistent=false)
      datastores = {}
      tgt_datastores = persistent ? cluster.persistent_datastores : cluster.datastores
      tgt_datastores.each { |ds|
        if ds.real_free_space - disk_space > DISK_THRESHOLD
          datastores[ds] = score_datastore(ds, disk_space)
        end
      }
      return nil if datastores.empty?
      pick_random_with_score(datastores)
    end

    def find_persistent_datastore(dc_name, cluster_name, disk_space)
      cluster = get_cluster(dc_name, cluster_name)
      return nil if cluster.nil?

      chosen_datastore = nil
      @lock.synchronize do
        chosen_datastore = pick_datastore(cluster, disk_space, true)
        break if chosen_datastore.nil?

        chosen_datastore.unaccounted_space += disk_space
      end
      chosen_datastore
    end

    def find_resources(memory, disk_space)
      cluster = nil
      datastore = nil

      # account for swap
      disk_space += memory

      @lock.synchronize do
        resources = filter_used_resources(disk_space, memory)

        scored_resources = {}
        resources.each do |resource|
          cluster, datastore = resource
          scored_resources[resource] = score_resource(cluster, datastore, memory, disk_space)
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
        datastore.unaccounted_space += disk_space
      end

      [cluster, datastore]
    end

    def find_resources_near_persistent_disk(disk_locality, memory, disk_space)
      disk = Models::Disk[disk_locality]
      raise "Disk not found: #{disk_locality}" if disk.nil?

      # account for swap
      disk_space += memory

      cluster = nil
      datastore = nil
      found = false

      # locality only if the given disk is a persistent disk
      if disk.path && validate_persistent_datastore(disk.datacenter, disk.datastore)
        datacenter = datacenters.values.find { |dc| dc.name == disk.datacenter }
        datacenter.clusters.each do |c|
          c.persistent_datastores.each do |ds|
            if ds.name == disk.datastore
              @logger.info("Found #{c.name} @ #{c.mob}")
              cluster = c
              break
            end
          end
        end

        raise "Could not find disk local resources for: #{disk.pretty_inspect}" if cluster.nil?

        # Make sure there is enough space
        @lock.synchronize do
          break if cluster.real_free_memory - memory < MEMORY_THRESHOLD

          # Find a datastore with sufficient free space
          datastore = pick_datastore(cluster, disk_space)
          break if datastore.nil?

          datastore.unaccounted_space += disk_space
          cluster.unaccounted_memory += memory
          found = true
        end
      end

      unless found
        @logger.info("Disk was not allocated yet, allocating resources based on system capacity")
        cluster, datastore = find_resources(memory, disk_space)
      end

      [cluster, datastore]
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
