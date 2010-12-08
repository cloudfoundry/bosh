$:.unshift(File.expand_path("../vsphere" ,__FILE__))

module Bosh::Director

  module CloudProviders
    autoload :VSphere, "director/cloud/vsphere/client"
  end

  class VSphereCloud

    attr_accessor :client

    def initialize(options)
      @vcenters = options["vcenters"]
      raise "Invalid number of VCenters" unless @vcenters.size == 1
      @vcenter = @vcenters[0]

      @agent_properties = options["agent"]

      @client = CloudProviders::VSphere::Client.new("https://#{@vcenter["host"]}/sdk/vimService", options)
      @client.login(@vcenter["user"], @vcenter["password"], "en")

      @resources = CloudProviders::VSphere::Resources.new(@client, @vcenter)

      @lock = Mutex.new
      @locks = {}
      @locks_mutex = Mutex.new

      @logger = Config.logger
    end

    def create_stemcell(image, _)
      result = nil
      Dir.mktmpdir do |temp_dir|
        @logger.debug("extracting stemcell to: #{temp_dir}")
        output = `tar -C #{temp_dir} -xzf #{image} 2>&1`
        raise "Corrupt image, tar exit status: #{$?.exitstatus} output: #{output}" if $?.exitstatus != 0

        ovf_file = Dir.entries(temp_dir).find {|entry| File.extname(entry) == ".ovf"}
        raise "Missing OVF" if ovf_file.nil?
        ovf_file = File.join(temp_dir, ovf_file)

        name = "sc-#{generate_unique_name}"
        @logger.debug("generated name: #{name}")

        # TODO: make stemcell friendly version of the calls below
        cluster = @resources.find_least_loaded_cluster(1)
        datastore = @resources.find_least_loaded_datastore(cluster, 1)
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
        cluster = @resources.find_least_loaded_cluster(1)
        datastore = @resources.find_least_loaded_datastore(cluster, 1)
      else
        # TODO: get cluster based on disk locality
        # TODO: get datastore based on disk locality
      end

      name = "vm-#{generate_unique_name}"
      @logger.debug("creating vm: #{name} on #{cluster.mob} stored in #{datastore.mob}")

      replicated_stemcell_vm = replicate_stemcell(cluster, datastore, stemcell)
      replicated_stemcell_properties = client.get_properties(replicated_stemcell_vm, "VirtualMachine",
                                                        ["config.hardware.device", "snapshot"])
      devices = replicated_stemcell_properties["config.hardware.device"]
      snapshot = replicated_stemcell_properties["snapshot"]

      config = CloudProviders::VSphere::VirtualMachineConfigSpec.new
      config.memoryMB = memory
      config.numCPUs = cpu
      config.deviceChange = []

      system_disk = devices.find {|device| device.kind_of?(CloudProviders::VSphere::VirtualDisk)}
      existing_nic = devices.find {|device| device.kind_of?(CloudProviders::VSphere::VirtualEthernetCard)}

      file_name = "[#{datastore.name}] #{name}/ephemeral_disk.vmdk"
      ephemeral_disk_config = create_disk_config_spec(datastore, file_name, system_disk.controllerKey, disk,
                                                      :create => true)
      config.deviceChange << ephemeral_disk_config

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

      @logger.debug("cloning vm: #{replicated_stemcell_vm} to #{name}")

      task = clone_vm(replicated_stemcell_vm, name, cluster.datacenter.vm_folder, cluster.resource_pool,
                      :datastore => datastore.mob, :linked => true, :snapshot => snapshot.currentSnapshot,
                      :config => config)
      vm = client.wait_for_task(task)

      vm_properties = client.get_properties(vm, "VirtualMachine", ["config.hardware.device"])
      devices = vm_properties["config.hardware.device"]

      env = build_agent_env(agent_id, networks, devices, system_disk, ephemeral_disk_config.device)
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

    def replicate_stemcell(cluster, datastore, stemcell)
      stemcell_vm = client.find_by_inventory_path([cluster.datacenter.name, "vm",
                                                   cluster.datacenter.template_folder_name, stemcell])
      stemcell_properties    = client.get_properties(stemcell_vm, "VirtualMachine", ["datastore"])

      if stemcell_properties["datastore"] != datastore.mob
        @logger.debug("stemcell lives on a different datastore, looking for a local copy of: #{stemcell}.")
        local_stemcell_name    = "#{stemcell} / #{datastore.mob}"
        local_stemcell_path    = [cluster.datacenter.name, "vm", cluster.datacenter.template_folder_name,
                                  local_stemcell_name]
        replicated_stemcell_vm = client.find_by_inventory_path(local_stemcell_path)

        if replicated_stemcell_vm.nil?
          @logger.debug("cluster doesn't have stemcell #{stemcell}, replicating")
          lock = nil
          @locks_mutex.synchronize do
            lock = @locks[local_stemcell_name]
            if lock.nil?
              lock = @locks[local_stemcell_name] = Mutex.new
            end
          end

          lock.synchronize do
            replicated_stemcell_vm = client.find_by_inventory_path(local_stemcell_path)
            if replicated_stemcell_vm.nil?
              @logger.debug("cloning #{stemcell_vm} to #{local_stemcell_name}")
              task = clone_vm(stemcell_vm, local_stemcell_name, cluster.datacenter.template_folder,
                              cluster.resource_pool, :datastore => datastore.mob)
              replicated_stemcell_vm = client.wait_for_task(task)
              task = take_snapshot(replicated_stemcell_vm, "initial")
              client.wait_for_task(task)
            end
          end
        end
        result = replicated_stemcell_vm
      else
        result = stemcell_vm
      end
      result
    end

    def build_agent_env(agent_id, networks, devices, system_disk, ephemeral_disk)
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

      disk_env = {
        "system" => system_disk.unitNumber,
        "ephemeral" => ephemeral_disk.unitNumber
      }

      env = {}
      env["agent_id"] = agent_id
      env["networks"] = network_env
      env["disks"] = disk_env
      env.merge!(@agent_properties)
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
      result = client.wait_for_task(task)
      if result.attempted.nil?
        raise "Could not power on VM: #{result.notAttempted.localizedMessage}"
      else
        task = result.attempted.first.task
        client.wait_for_task(task)
      end
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

            http_client.post(device_url.url, disk_file, {"Content-Type" => "application/x-vnd.vmware-streamVmdk",
                                "Content-Length" => disk_file_size})

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

      pool = ActionPool::Pool.new(:min_threads => 1, :max_threads => 32)
      index = 0

      datacenters.each do |datacenter|
        vm_folder_path = [datacenter.name, "vm", datacenter.vm_folder_name]
        vm_folder = client.find_by_inventory_path(vm_folder_path)
        vms = client.get_managed_objects("VirtualMachine", :root => vm_folder)
        next if vms.empty?

        vm_properties = client.get_properties(vms, "VirtualMachine", ["runtime.powerState"])

        vm_properties.each do |_, properties|
          pool.process do
            @lock.synchronize {index += 1}
            vm = properties[:obj]
            @logger.debug("Deleting #{index}/#{vms.size}: #{vm}")
            if properties["runtime.powerState"] != CloudProviders::VSphere::VirtualMachinePowerState::PoweredOff
              @logger.debug("Powering off #{index}/#{vms.size}: #{vm}")
              power_off_vm(vm)
            end
            task = client.service.destroy_Task(CloudProviders::VSphere::DestroyRequestType.new(vm)).returnval
            client.wait_for_task(task)
          end
        end
      end

      sleep(0.1) while pool.working + pool.action_size > 0
    end

  end
end