$:.unshift(File.expand_path("../vsphere" ,__FILE__))

module Bosh::Director

  module CloudProviders
    autoload :VSphere, "director/cloud/vsphere/client"
  end

  class VSphereCloud

    class ClusterStats

      class Datastore
        attr_accessor :mob
        attr_accessor :name
        attr_accessor :total_space
        attr_accessor :free_space
        attr_accessor :unaccounted_space
      end

      class Datacenter
        attr_accessor :mob
        attr_accessor :vm_folder
        attr_accessor :vm_folder_name
        attr_accessor :template_folder
        attr_accessor :template_folder_name
        attr_accessor :name
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
      end

      attr_accessor :timestamp
      attr_accessor :clusters

      def initialize
        @clusters = {}
        @timestamp = 0
      end

    end

    attr_accessor :client

    def initialize(options)
      @vcenters = options["vcenters"]
      raise "Invalid number of VCenters" unless @vcenters.size == 1
      @vcenter = @vcenters[0]

      @agent_properties = options["agent"]

      @client = CloudProviders::VSphere::Client.new("https://#{@vcenter["host"]}/sdk/vimService", options)
      @client.login(@vcenter["user"], @vcenter["password"], "en")

      @lock = Mutex.new
      @locks = {}
      @locks_mutex = Mutex.new

      @logger = Config.logger
    end

    def create_stemcell(image, _)
      result = nil
      Dir.mktmpdir do |temp_dir|
        @logger.debug("extracting stemcell to: #{temp_dir}")
        `tar -C #{temp_dir} -xzf #{image}`
        raise "Corrupt image" if $?.exitstatus != 0

        ovf_file = Dir.entries(temp_dir).find {|entry| File.extname(entry) == ".ovf"}
        raise "Missing OVF" if ovf_file.nil?
        ovf_file = File.join(temp_dir, ovf_file)

        name = "sc-#{generate_unique_name}"
        @logger.debug("generated name: #{name}")

        # TODO: make stemcell friendly version of the calls below
        cluster = find_least_loaded_cluster(1)
        datastore = find_least_loaded_datastore(cluster, 1)
        @logger.debug("deploying to: #{cluster.mob} / #{datastore.mob}")

        import_spec_result = import_ovf(name, ovf_file, cluster.resource_pool, datastore.mob)
        lease = obtain_nfc_lease(cluster.resource_pool, import_spec_result.importSpec,
                                 cluster.datacenter.template_folder)
        state = wait_for_nfc_lease(lease)
        raise 'Could not acquire HTTP NFC lease' unless state == CloudProviders::VSphere::HttpNfcLeaseState::Ready

        upload_ovf(ovf_file, lease, import_spec_result.fileItem)
        result = name
      end
      result
    end

    def delete_stemcell(stemcell)
      # delete VM by mob id
    end

    def create_vm(agent_id, stemcell, resource_pool, networks, disk_locality = nil)
      memory = resource_pool["ram"]
      disk = resource_pool["disk"]
      cpu = resource_pool["cpu"]

      cluster = nil
      datastore = nil

      if disk_locality.nil?
        cluster = find_least_loaded_cluster(memory)
        datastore = find_least_loaded_datastore(cluster, disk)
      else
        # TODO: get cluster based on disk locality
        # TODO: get datastore based on disk locality
      end

      name = "vm-#{generate_unique_name}"
      stemcell_vm = client.find_by_inventory_path([cluster.datacenter.name, "vm",
                                                   cluster.datacenter.template_folder_name, stemcell])

      @logger.debug("creating vm: #{name} on #{cluster.mob} stored in #{datastore.mob}")

      local_stemcell_vm = nil
      stemcell_properties = client.get_properties(stemcell_vm, "VirtualMachine", ["datastore"])

      if stemcell_properties["datastore"] != datastore.mob
        @logger.debug("stemcell lives on a different datastore, looking for a local copy of: #{stemcell}.")
        local_stemcell_name = "#{stemcell} / #{datastore.mob}"
        local_stemcell_path = [cluster.datacenter.name, "vm", cluster.datacenter.template_folder_name,
                               local_stemcell_name]
        local_stemcell_vm = client.find_by_inventory_path(local_stemcell_path)

        if local_stemcell_vm.nil?
          @logger.debug("cluster doesn't have stemcell #{stemcell}, replicating")
          lock = nil
          @locks_mutex.synchronize do
            lock = @locks[local_stemcell_name]
            if lock.nil?
              lock = @locks[local_stemcell_name] = Mutex.new
            end
          end

          lock.synchronize do
            local_stemcell_vm = client.find_by_inventory_path(local_stemcell_path)
            if local_stemcell_vm.nil?
              @logger.debug("cloning #{stemcell_vm} to #{local_stemcell_name}")
              task = clone_vm(stemcell_vm, local_stemcell_name, cluster.datacenter.template_folder,
                              cluster.resource_pool, :datastore => datastore.mob)
              local_stemcell_vm = client.wait_for_task(task)
              task = take_snapshot(local_stemcell_vm, "initial")
              client.wait_for_task(task)
            end
          end
        end
      else
        local_stemcell_vm = stemcell_vm
      end

      local_stemcell_properties = client.get_properties(local_stemcell_vm, "VirtualMachine",
                                                        ["config.hardware.device", "snapshot"])
      devices = local_stemcell_properties["config.hardware.device"]
      snapshot = local_stemcell_properties["snapshot"]

      config = CloudProviders::VSphere::VirtualMachineConfigSpec.new
      config.memoryMB = memory
      config.numCPUs = cpu
      config.deviceChange = []

      primary_disk = devices.find {|device| device.kind_of?(CloudProviders::VSphere::VirtualDisk)}
      existing_nic = devices.find {|device| device.kind_of?(CloudProviders::VSphere::VirtualEthernetCard)}

      file_name = "[#{datastore.name}] #{name}/ephemeral_disk.vmdk"
      disk_config = create_disk_config_spec(datastore, file_name, primary_disk.controllerKey, disk, :create => true)
      config.deviceChange << disk_config

      networks.each_value do |network|
        v_network_name = network["cloud_properties"]["name"]
        network_mob = client.find_by_inventory_path([cluster.datacenter.name, "network", v_network_name])
        nic_config = create_nic_config_spec(v_network_name, network_mob, existing_nic.controllerKey)
        config.deviceChange << nic_config
      end

      nics = devices.select {|device| device.kind_of?(CloudProviders::VSphere::VirtualEthernetCard)}
      nics.each do |nic|
        nic_config = create_delete_device_spec(nic)
        config.deviceChange << nic_config
      end

      fix_device_unit_numbers(devices, config.deviceChange)

      @logger.debug("cloning vm: #{local_stemcell_vm} to #{name}")

      task = clone_vm(local_stemcell_vm, name, cluster.datacenter.vm_folder, cluster.resource_pool,
                      :datastore => datastore.mob, :linked => true, :snapshot => snapshot.currentSnapshot,
                      :config => config)
      vm = client.wait_for_task(task)

      vm_properties = client.get_properties(vm, "VirtualMachine", ["config.hardware.device"])
      devices = vm_properties["config.hardware.device"]

      env = build_agent_env(agent_id, networks, devices)
      @logger.debug("setting VM env: #{env.pretty_inspect}")
      set_agent_env(vm, env)

      @logger.debug("powering on VM: #{vm} (#{name})")
      power_on_vm(cluster.datacenter.mob, vm)
      vm
    end

    def delete_vm(vm_cid)
      vm = CloudProviders::VSphere::ManagedObjectReference.new(vm_cid)
      vm.xmlattr_type = "VirtualMachine"

      power_state = client.get_property(vm, "VirtualMachine", "runtime.powerState")
      if power_state != CloudProviders::VSphere::VirtualMachinePowerState::PoweredOff
        power_off_vm(vm)
      end

      task = client.service.destroy_Task(CloudProviders::VSphere::DestroyRequestType.new(vm)).returnval
      client.wait_for_task(task)
    end

    def configure_networks(vm, networks)

    end

    def attach_disk(vm, disk)
      # make sure vm and disk are in the same cluster
      # if not move the disk to the VM cluster
      # attach disk
    end

    def detach_disk(vm, disk)
      # detach disk from VM
    end

    def create_disk(size, vm_locality = nil)
      # find cluster, either by vm locality or cluster with most resources
      # create disk
    end

    def delete_disk(disk)
      # delete disk by disk id
    end

    def validate_deployment(old_manifest, new_manifest)
      # TODO: still needed? what does it verify? cloud properties? should be replaced by normalize cloud properties?
    end

    def build_agent_env(agent_id, networks, devices)
      nics = {}

      devices.each do |device|
        if device.kind_of?(CloudProviders::VSphere::VirtualEthernetCard)
          v_network_name = device.backing.deviceName
          allocated_networks = nics[v_network_name] || []
          allocated_networks << device
          nics[v_network_name] = allocated_networks
        end
      end

      network_env = {}
      networks.each do |network_name, network|
        network_entry = network.dup
        v_network_name = network["cloud_properties"]["name"]
        nic = nics[v_network_name].pop
        network_entry["mac"] = nic.macAddress
        network_env[network_name] = network_entry
      end

      env = {}
      env["agent_id"] = agent_id
      env["networks"] = network_env
      env.merge!(@agent_properties)
      # TODO: redis location, disk config
      env
    end

    def set_agent_env(vm, env)
      env_property = create_app_property_spec("Bosh_Agent_Properties", "string", Yajl::Encoder.encode(env))

      app_config_spec = CloudProviders::VSphere::VmConfigSpec.new
      app_config_spec.property = [env_property]
      # make sure the transport is set correctly, needed for guest to access these properties
      app_config_spec.ovfEnvironmentTransport = ["com.vmware.guestInfo"]

      vm_config_spec = CloudProviders::VSphere::VirtualMachineConfigSpec.new
      vm_config_spec.vAppConfig = app_config_spec

      request = CloudProviders::VSphere::ReconfigVMRequestType.new(vm, vm_config_spec)
      task = client.service.reconfigVM_Task(request).returnval
      client.wait_for_task(task)
    end

    def find_least_loaded_cluster(memory)
      result = nil
      @lock.synchronize do
        max_free_memory = 0.0

        clusters = cluster_stats.clusters
        clusters = clusters.select do |cluster|
          free_memory = cluster.free_memory - cluster.unaccounted_memory
          max_free_memory = free_memory if free_memory > max_free_memory
          cluster.free_memory - cluster.unaccounted_memory - memory > 128
        end

        # TODO: what if there are no free clusters?

        clusters.sort! {|c1, c2| score_cluster(c2, memory, max_free_memory) - score_cluster(c1, memory, max_free_memory)}
        clusters = clusters[0..2]

        scores = []
        score_sum = 0
        clusters.each do |cluster|
          scores << score_cluster(cluster, memory, max_free_memory)
          score_sum += scores.last
        end

        scores.map! {|score| score / score_sum}
        rand_sample = rand

        result = if rand_sample < scores[0]
          clusters[0]
        elsif rand_sample < scores[0] + scores[1]
          clusters[1]
        else
          clusters[2]
        end

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

        # TODO: what if there is no free datastore?

        datastores.sort!{|ds1, ds2| score_datastore(ds2, space) - score_datastore(ds1, space)}
        result = datastores.first

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
      free_memory = cluster.free_memory - cluster.unaccounted_memory - memory
      free_memory = free_memory.to_f
      free_memory / max_free_memory * 0.5 + cluster.idle_cpu * 0.25 + (free_memory / cluster.total_memory) * 0.25
    end

    def clone_vm(vm, name, folder, resource_pool, options={})
      relocation_spec = CloudProviders::VSphere::VirtualMachineRelocateSpec.new
      relocation_spec.datastore = options[:datastore] if options[:datastore]
      if options[:linked]
        relocation_spec.diskMoveType =
                CloudProviders::VSphere::VirtualMachineRelocateDiskMoveOptions::CreateNewChildDiskBacking
      end
      relocation_spec.pool = resource_pool

      clone_spec = CloudProviders::VSphere::VirtualMachineCloneSpec.new
      clone_spec.config = options[:config] if options[:config]
      clone_spec.location = relocation_spec
      clone_spec.powerOn = options[:power_on] ? true : false
      clone_spec.snapshot = options[:snapshot] if options[:snapshot]
      clone_spec.template = false

      client.service.cloneVM_Task(CloudProviders::VSphere::CloneVMRequestType.new(vm, folder, name,
                                                                                  clone_spec)).returnval
    end

    def take_snapshot(vm, name)
      request = CloudProviders::VSphere::CreateSnapshotRequestType.new(vm)
      request.name = name
      request.memory = false
      request.quiesce = false
      client.service.createSnapshot_Task(request).returnval
    end

    def cluster_stats
      @cluster_stats = ClusterStats.new if @cluster_stats.nil?

      if Time.now.to_i - @cluster_stats.timestamp > 60
        datacenters = client.get_managed_objects("Datacenter")
        datacenter_properties = client.get_properties(datacenters, "Datacenter", ["name"])

        datacenter_names = Set.new
        @vcenter["datacenters"].each {|datacenter| datacenter_names << datacenter["name"]}
        datacenter_properties.delete_if {|_, properties| !datacenter_names.include?(properties["name"])}

        datacenters = {}
        datacenter_properties.each_value do |properties|
          datacenter = ClusterStats::Datacenter.new
          datacenter.mob = properties[:obj]
          datacenter.name = properties["name"]
          datacenters[datacenter.name] = datacenter
        end

        global_cluster_properties = {}
        @vcenter["datacenters"].each do |datacenter_spec|
          datacenter = datacenters[datacenter_spec["name"]]
          datacenter.vm_folder = client.find_by_inventory_path([datacenter.name, "vm", datacenter_spec["vm_folder"]])
          datacenter.vm_folder_name = datacenter_spec["vm_folder"]
          datacenter.template_folder = client.find_by_inventory_path([datacenter.name, "vm",
                                                                      datacenter_spec["template_folder"]])
          datacenter.template_folder_name = datacenter_spec["template_folder"]
          cluster_mobs = client.get_managed_objects("ClusterComputeResource", :root => datacenter.mob)
          cluster_properties = client.get_properties(cluster_mobs, "ClusterComputeResource", ["name", "datastore",
                                                                                              "resourcePool"])

          cluster_names = Set.new(datacenter_spec["clusters"])
          cluster_properties.delete_if {|_, properties| !cluster_names.include?(properties["name"])}
          cluster_properties.each do |name, properties|
            properties[:datacenter] = datacenter
            global_cluster_properties[name] = properties
          end
        end
        cluster_properties = global_cluster_properties

        hosts = client.get_managed_objects("HostSystem")
        host_properties = client.get_properties(hosts, "HostSystem", ["parent", "hardware.memorySize",
                                                                      "runtime.inMaintenanceMode"])
        host_properties.delete_if do |_, properties|
          properties["runtime.inMaintenanceMode"] == "true" || !cluster_properties.has_key?(properties["parent"])
        end

        hosts = []
        host_properties.each_value do |properties|
          hosts << properties[:obj]
        end

        cluster_resources = {}
        perf_counters = get_perf_counters(hosts, ["cpu.usage.average", "mem.usage.average"], :max_sample => 5)
        perf_counters.each do |host_mob, perf_counter|
          host = host_properties[host_mob]
          cluster_mob = host["parent"]
          resources = cluster_resources[cluster_mob] || {
            :samples => 0,
            :total_memory => 0,
            :free_memory => 0,
            :cpu_usage => 0
          }

          host_memory = host["hardware.memorySize"].to_i
          host_memory_used = (average_csv(perf_counter["mem.usage.average"]) / 10000)

          resources[:samples] += 1
          resources[:total_memory] += host_memory
          resources[:free_memory] += ((1 - host_memory_used) * host_memory).to_i
          resources[:cpu_usage] += average_csv(perf_counter["cpu.usage.average"]) / 100
          cluster_resources[cluster_mob] = resources
        end

        datastores = []
        cluster_properties.each_value {|properties| datastores.concat(properties["datastore"])}
        datastore_properties = client.get_properties(datastores, "Datastore", ["summary.freeSpace", "summary.capacity",
                                                                               "summary.multipleHostAccess", "name"])
        datastore_properties.delete_if {|_, properties| properties["summary.multipleHostAccess"] == "false"}

        clusters = []
        cluster_properties.each_value do |properties|
          cluster = ClusterStats::Cluster.new
          cluster.mob = properties[:obj]
          cluster.name = properties["name"]
          cluster.resource_pool = properties["resourcePool"]
          cluster.datacenter = properties[:datacenter]

          resources = cluster_resources[cluster.mob]
          cluster.idle_cpu = (100 - resources[:cpu_usage]/resources[:samples]) / 100
          cluster.total_memory = resources[:total_memory]/(1024 * 1024)
          cluster.free_memory = resources[:free_memory]/(1024 * 1024)
          cluster.unaccounted_memory = 0

          cluster_datastores = []
          properties["datastore"].each do |datastore|
            datastore = datastore_properties[datastore]
            if datastore
              cluster_datastore = ClusterStats::Datastore.new
              cluster_datastore.mob = datastore[:obj]
              cluster_datastore.name = datastore["name"]
              cluster_datastore.free_space = datastore["summary.freeSpace"].to_i / (1024 * 1024)
              cluster_datastore.total_space = datastore["summary.capacity"].to_i / (1024 * 1024)
              cluster_datastore.unaccounted_space = 0
              cluster_datastores << cluster_datastore
            end
          end
          cluster.datastores = cluster_datastores

          clusters << cluster
        end

        @cluster_stats.clusters = clusters
        @cluster_stats.timestamp = Time.now.to_i
      end

      @cluster_stats
    end

    def get_perf_counters(mobs, names, options = {})
      counters = find_perf_counters(mobs.first, names)
      counter_reverse_map = {}
      counters.each do |key, value|
        counter_reverse_map[value.counterId] = key
      end

      metric_ids = counters.values

      queries = []
      mobs.each do |mob|
        query = CloudProviders::VSphere::PerfQuerySpec.new
        query.entity = mob
        query.metricId = metric_ids
        query.format = CloudProviders::VSphere::PerfFormat::Csv
        query.intervalId = options[:interval_id] || 20
        query.maxSample = options[:max_sample]
        queries << query
      end

      query_perf_request = CloudProviders::VSphere::QueryPerfRequestType.new(client.service_content.perfManager,
                                                                             queries)
      # TODO: shard and send requests in parallel for better performance
      query_perf_response = client.service.queryPerf(query_perf_request)


      result = {}
      query_perf_response.each do |mob_stats|
        mob_entry = {}
        counters = mob_stats.value
        counters.each do |counter_stats|
          counter_id = counter_stats.id.counterId
          values = counter_stats.value
          mob_entry[counter_reverse_map[counter_id]] = values
        end
        result[mob_stats.entity] = mob_entry
      end
      result
    end

    def find_perf_counters(mob, names)
      request = CloudProviders::VSphere::QueryAvailablePerfMetricRequestType.new(
              client.service_content.perfManager, mob)
      request.intervalId = 300
      metrics = client.service.queryAvailablePerfMetric(request)

      metric_ids = metrics.collect {|metric| metric.counterId}
      request = CloudProviders::VSphere::QueryPerfCounterRequestType.new(client.service_content.perfManager, metric_ids)
      metrics_info = client.service.queryPerfCounter(request)

      selected_metrics_info = {}
      metrics_info.each do |perf_counter_info|
        name = "#{perf_counter_info.groupInfo.key}.#{perf_counter_info.nameInfo.key}.#{perf_counter_info.rollupType}"
        selected_metrics_info[perf_counter_info.key] = name if names.include?(name)
      end

      result = {}
      metrics.select do |metric|
        metric_info = selected_metrics_info[metric.counterId]
        result[metric_info] = metric if metric_info
      end
      result
    end

    def average_csv(csv)
      values = csv.split(",")
      result = 0
      values.each {|v| result += v.to_f}
      result / values.size
    end

    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
    end

    def create_disk_config_spec(datastore, file_name, controller_key, space, options = {})
      backing_info = CloudProviders::VSphere::VirtualDiskFlatVer2BackingInfo.new
      backing_info.datastore = datastore.mob
      backing_info.diskMode = CloudProviders::VSphere::VirtualDiskMode::Persistent
      backing_info.fileName = file_name

      virtual_disk = CloudProviders::VSphere::VirtualDisk.new
      virtual_disk.key = -1
      virtual_disk.controllerKey = controller_key
      virtual_disk.backing = backing_info
      virtual_disk.capacityInKB = space * 1024

      device_config_spec = CloudProviders::VSphere::VirtualDeviceConfigSpec.new
      device_config_spec.device = virtual_disk
      device_config_spec.operation = CloudProviders::VSphere::VirtualDeviceConfigSpecOperation::Add
      if options[:create]
        device_config_spec.fileOperation = CloudProviders::VSphere::VirtualDeviceConfigSpecFileOperation::Create
      end
      device_config_spec
    end

    def create_nic_config_spec(name, network, controller_key)
      backing_info = CloudProviders::VSphere::VirtualEthernetCardNetworkBackingInfo.new
      backing_info.deviceName = name
      backing_info.network = network

      nic = CloudProviders::VSphere::VirtualVmxnet3.new
      nic.key = -1
      nic.controllerKey = controller_key
      nic.backing = backing_info

      device_config_spec = CloudProviders::VSphere::VirtualDeviceConfigSpec.new
      device_config_spec.device = nic
      device_config_spec.operation = CloudProviders::VSphere::VirtualDeviceConfigSpecOperation::Add
      device_config_spec
    end

    def create_delete_device_spec(device, options = {})
      device_config_spec = CloudProviders::VSphere::VirtualDeviceConfigSpec.new
      device_config_spec.device = device
      device_config_spec.operation = CloudProviders::VSphere::VirtualDeviceConfigSpecOperation::Remove
      if options[:destroy]
        device_config_spec.fileOperation = CloudProviders::VSphere::VirtualDeviceConfigSpecFileOperation::Destroy
      end
      device_config_spec
    end

    def fix_device_unit_numbers(devices, device_changes)
      max_unit_numbers = {}
      devices.each do |device|
        if device.controllerKey
          max_unit_number = max_unit_numbers[device.controllerKey]
          if max_unit_number.nil? || max_unit_number < device.unitNumber
            max_unit_numbers[device.controllerKey] = device.unitNumber
          end
        end
      end

      device_changes.each do |device_change|
        device = device_change.device
        if device.controllerKey && device.unitNumber.nil?
          max_unit_number = max_unit_numbers[device.controllerKey] || 0
          device.unitNumber = max_unit_number + 1
          max_unit_numbers[device.controllerKey] = device.unitNumber
        end
      end
    end

    def create_app_property_spec(id, type, value)
      property_info = CloudProviders::VSphere::VAppPropertyInfo.new
      property_info.key = -1
      property_info.id = id
      property_info.type = type
      property_info.value = value

      property_spec = CloudProviders::VSphere::VAppPropertySpec.new
      property_spec.operation = CloudProviders::VSphere::ArrayUpdateOperation::Add
      property_spec.info = property_info
      property_spec
    end

    def power_on_vm(datacenter, vm)
      request = CloudProviders::VSphere::PowerOnMultiVMRequestType.new(datacenter, [vm])
      task = client.service.powerOnMultiVM_Task(request).returnval
      client.wait_for_task(task)
    end

    def power_off_vm(vm)
      request = CloudProviders::VSphere::PowerOffVMRequestType.new(vm)
      task = client.service.powerOffVM_Task(request).returnval
      client.wait_for_task(task)
    end

    def import_ovf(name, ovf, resource_pool, datastore)
      import_spec_params = CloudProviders::VSphere::OvfCreateImportSpecParams.new
      import_spec_params.entityName = name
      import_spec_params.locale = 'US'
      import_spec_params.deploymentOption = ''

      ovf_file = File.open(ovf)
      ovf_descriptor = ovf_file.read
      ovf_file.close

      request = CloudProviders::VSphere::CreateImportSpecRequestType.new(
              client.service_content.ovfManager, ovf_descriptor, resource_pool, datastore, import_spec_params)
      client.service.createImportSpec(request).returnval
    end

    def obtain_nfc_lease(resource_pool, import_spec, folder)
      request = CloudProviders::VSphere::ImportVAppRequestType.new(resource_pool, import_spec, folder)
      client.service.importVApp(request).returnval
    end

    def wait_for_nfc_lease(lease)
      loop do
        state = client.get_property(lease, 'HttpNfcLease', 'state')
        unless state == CloudProviders::VSphere::HttpNfcLeaseState::Initializing
          return state
        end
        sleep(1.0)
      end
    end

    def upload_ovf(ovf, lease, file_items)
      info = client.get_property(lease, 'HttpNfcLease', 'info')
      lease_updater = CloudProviders::VSphere::LeaseUpdater.new(client, lease)

      info.deviceUrl.each do |device_url|
        device_key = device_url.importKey
        file_items.each do |file_item|
          if device_key == file_item.deviceId
            http_client = HTTPClient.new
            http_client.send_timeout = 14400 # 4 hours
            http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

            disk_file_path = File.join(File.dirname(ovf), file_item.path)
            # TODO; capture the error if file is not found a provide a more meaningful error
            disk_file = File.open(disk_file_path)
            disk_file_size = File.size(disk_file_path)

            progress_thread = Thread.new do
              loop do
                # TODO: fix progress calculation to work across multiple disks
                lease_updater.progress = disk_file.pos * 100 / disk_file_size
                sleep(2)
              end
            end

            @logger.debug("uploading disk to: #{device_url.url}")

            unless @vcenter["tunnel"]
              http_client.post(device_url.url, disk_file, {"Content-Type" => "application/x-vnd.vmware-streamVmdk",
                                  "Content-Length" => disk_file_size})
            else
              # Only used for development
              ssh_tunnel(device_url.url) do |url|
                @logger.debug("using tunnel: #{url}")
                http_client.post(url, disk_file, {"Content-Type" => "application/x-vnd.vmware-streamVmdk",
                                                  "Content-Length" => disk_file_size})
              end
            end

            progress_thread.kill
            disk_file.close
          end
        end
      end
      lease_updater.finish
      info.entity
    end

    def delete_all_vms
      clusters = cluster_stats.clusters
      datacenters = Set.new

      clusters.each do |cluster|
        datacenters << cluster.datacenter
      end

      datacenters.each do |datacenter|
        vm_folder_path = [datacenter.name, "vm", datacenter.vm_folder_name]
        vm_folder = client.find_by_inventory_path(vm_folder_path)
        vms = client.get_managed_objects("VirtualMachine", :root => vm_folder)
        vm_properties = client.get_properties(vms, "VirtualMachine", ["runtime.powerState"])

        pool = ActionPool::Pool.new(:min_threads => 1, :max_threads => 32)

        index = 1

        vm_properties.each do |_, properties|
          pool.process do
            vm = properties[:obj]
            @logger.log("Deleting #{index}/#{vms.size}: #{vm}")
            if properties["runtime.powerState"] != CloudProviders::VSphere::VirtualMachinePowerState::PoweredOff
              @logger.log("Powering off #{index}/#{vms.size}: #{vm}")
              power_off_vm(vm)
            end
            task = client.service.destroy_Task(CloudProviders::VSphere::DestroyRequestType.new(vm)).returnval
            client.wait_for_task(task)
            index += 1
          end
        end
      end

      sleep(0.1) while pool.working + pool.action_size > 0
    end

    def ssh_tunnel(url)
      port = 10000
      loop do
        `lsof -i :#{port}`
        break if $?.exitstatus == 1
        port += 1
      end

      uri = URI.parse(url)

      pid = fork
      if pid.nil?
        exec("ssh -n -L #{port}:#{uri.host}:#{uri.port} #{@vcenter["tunnel"]} -N")
      end

      @logger.debug("ssh tunnel pid: #{pid}")

      begin
        uri.host = "localhost"
        uri.port = port

        tries = 4
        begin
          @logger.debug("probing ssh tunnel on port: #{port}, tries left: #{tries}")
          http_client = HTTPClient.new
          http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
          http_client.head(uri.to_s)
        rescue
          tries -= 1
          if tries > 0
            sleep(5)
            retry
          end
        end

        yield uri.to_s
      ensure
        Process.kill(9, pid)
        @logger.debug("killed ssh tunnel: #{pid}")
      end
    end

  end
end