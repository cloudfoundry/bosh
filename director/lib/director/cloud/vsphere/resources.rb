module VSphereCloud

  class Resources

    class Datacenter
      attr_accessor :mob
      attr_accessor :name
      attr_accessor :clusters
      attr_accessor :vm_folder
      attr_accessor :vm_folder_name
      attr_accessor :template_folder
      attr_accessor :template_folder_name
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
      datacenters      = @client.get_managed_objects("Datacenter")
      properties       = @client.get_properties(datacenters, "Datacenter", ["name"])
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
        datacenter.clusters             = fetch_clusters(datacenter)
        datacenters[datacenter.name]    = datacenter
      end
      datacenters
    end

    def fetch_clusters(datacenter)
      datacenter_spec = datacenter.spec
      cluster_mobs    = @client.get_managed_objects("ClusterComputeResource", :root => datacenter.mob)
      properties      = @client.get_properties(cluster_mobs, "ClusterComputeResource",
                                               ["name", "datastore", "resourcePool", "host"])

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
        cluster.datastores         = fetch_datastores(cluster_properties["datastore"])

        fetch_cluster_utilization(cluster, cluster_properties["host"])

        clusters << cluster
      end
      clusters
    end

    def fetch_datastores(datastore_mobs)
      properties = @client.get_properties(datastore_mobs, "Datastore",
                                          ["summary.freeSpace", "summary.capacity",
                                           "summary.multipleHostAccess", "name"])
      properties.delete_if { |_, datastore_properties| datastore_properties["summary.multipleHostAccess"] == "false" }

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
      properties = @client.get_properties(host_mobs, "HostSystem",
                                         ["hardware.memorySize", "runtime.inMaintenanceMode"])
      properties.delete_if { |_, host_properties| host_properties["runtime.inMaintenanceMode"] == "true" }

      samples       = 0
      total_memory  = 0
      free_memory   = 0
      cpu_usage     = 0

      perf_counters = @client.get_perf_counters(host_mobs, ["cpu.usage.average", "mem.usage.average"], :max_sample => 5)
      perf_counters.each do |host_mob, perf_counter|
        host_properties          = properties[host_mob]
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
      values.each {|v| result += v.to_f}
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

    def find_least_loaded_cluster(memory)
      result = nil
      @lock.synchronize do
        max_free_memory = 0.0

        clusters = []
        datacenters.each_value do |datacenter|
          datacenter.clusters.each do |cluster|
            free_memory = cluster.real_free_memory
            if free_memory - memory > 128
              max_free_memory = free_memory if free_memory > max_free_memory
              clusters << cluster
            end
          end
        end

        raise "No available clusters" if clusters.empty?

        clusters.sort! {|cluster_1, cluster_2| score_cluster(cluster_2, memory, max_free_memory) -
            score_cluster(cluster_1, memory, max_free_memory)}
        clusters = clusters[0..2]

        cluster_scores = clusters.collect do |cluster|
          cluster_score = score_cluster(cluster, memory, max_free_memory)
          @logger.debug("Cluster: #{cluster.inspect} score: #{cluster_score}")
          [cluster, cluster_score]
        end
        result = pick_random_with_score(cluster_scores)

        @logger.debug("Picked: #{result.inspect}")

        result.unaccounted_memory += memory
      end

      result
    end

    def find_least_loaded_datastore(cluster, space)
      result = nil
      @lock.synchronize do
        datastores = cluster.datastores
        datastores = datastores.select do |datastore|
          datastore.free_space - datastore.unaccounted_space - space > 512
        end

        raise "No available datastore" if datastores.empty?

        datastores.sort!{|ds1, ds2| score_datastore(ds2, space) - score_datastore(ds1, space)}
        result = datastores.first

        @logger.debug("Picked: #{result.inspect}")

        result.unaccounted_space += space
      end
      result
    end

    def score_datastore(datastore, space)
      datastore.free_space - datastore.unaccounted_space - space
    end

    def score_cluster(cluster, memory, max_free_memory)
      # 50% based on how much free memory this cluster has relative to other clusters
      # 25% based on cpu usage
      # 25% based on how much free memory this cluster has as a whole
      free_memory = cluster.real_free_memory.to_f - memory
      free_memory / max_free_memory * 0.5 + cluster.idle_cpu * 0.25 + (free_memory / cluster.total_memory) * 0.25
    end

    def pick_random_with_score(elements)
      score_sum = 0
      elements.each { |element| score_sum += element[1] }

      random_score = rand * score_sum
      base_score = 0

      elements.find do |element|
        score = element[1]
        return element[0] if base_score + score > random_score
        base_score += score
      end

      # fall through
      elements.last[0]
    end

  end

end
