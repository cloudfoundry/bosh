require "director/cloud/vsphere/defaultDriver"
require "director/cloud/vsphere/client"
require "director/cloud/vsphere/lease_updater"
require "director/cloud/vsphere/resources"
require "director/cloud/vsphere/models/disk"

module SOAP

  module Mapping
    def self.fault2exception(fault, registry = nil)
      registry ||= Mapping::DefaultRegistry
      detail = if fault.detail
          soap2obj(fault.detail, registry) || ""
        else
          ""
        end
      if detail.is_a?(Mapping::SOAPException)
        begin
          e = detail.to_e
    remote_backtrace = e.backtrace
          e.set_backtrace(nil)
          raise e # ruby sets current caller as local backtrace of e => e2.
        rescue Exception => e
    e.set_backtrace(remote_backtrace + e.backtrace[1..-1])
          raise
        end
      else
        raise fault
      end
    end
  end
end

module VSphereCloud

  class Cloud

    BOSH_AGENT_PROPERTIES_ID = "Bosh_Agent_Properties"

    attr_accessor :client

    def initialize(options)
      @vcenters = options["vcenters"]
      raise "Invalid number of VCenters" unless @vcenters.size == 1
      @vcenter = @vcenters[0]

      @logger = Bosh::Director::Config.logger

      @agent_properties = options["agent"]

      @client = Client.new("https://#{@vcenter["host"]}/sdk/vimService", options)
      @client.login(@vcenter["user"], @vcenter["password"], "en")

      @resources = Resources.new(@client, @vcenter)

      @lock = Mutex.new
      @locks = {}
      @locks_mutex = Mutex.new
    end

    def create_stemcell(image, _)
      with_thread_name("create_stemcell(#{image}, _)") do
        result = nil
        Dir.mktmpdir do |temp_dir|
          @logger.info("Extracting stemcell to: #{temp_dir}")
          output = `tar -C #{temp_dir} -xzf #{image} 2>&1`
          raise "Corrupt image, tar exit status: #{$?.exitstatus} output: #{output}" if $?.exitstatus != 0

          ovf_file = Dir.entries(temp_dir).find {|entry| File.extname(entry) == ".ovf"}
          raise "Missing OVF" if ovf_file.nil?
          ovf_file = File.join(temp_dir, ovf_file)

          name = "sc-#{generate_unique_name}"
          @logger.info("Generated name: #{name}")

          # TODO: make stemcell friendly version of the calls below
          cluster = @resources.find_least_loaded_cluster(1)
          datastore = @resources.find_least_loaded_datastore(cluster, 1)
          @logger.info("Deploying to: #{cluster.mob} / #{datastore.mob}")

          import_spec_result = import_ovf(name, ovf_file, cluster.resource_pool, datastore.mob)
          lease = obtain_nfc_lease(cluster.resource_pool, import_spec_result.importSpec,
                                   cluster.datacenter.template_folder)
          @logger.info("Waiting for NFC lease")
          state = wait_for_nfc_lease(lease)
          raise "Could not acquire HTTP NFC lease" unless state == HttpNfcLeaseState::Ready

          @logger.info("Uploading")
          vm = upload_ovf(ovf_file, lease, import_spec_result.fileItem)
          result = name

          @logger.info("Removing NICs")
          devices = client.get_property(vm, "VirtualMachine", "config.hardware.device", :ensure_all => true)
          config = VirtualMachineConfigSpec.new
          config.deviceChange = []

          nics = devices.select {|device| device.kind_of?(VirtualEthernetCard)}
          nics.each do |nic|
            nic_config = create_delete_device_spec(nic)
            config.deviceChange << nic_config
          end
          client.reconfig_vm(vm, config)

          @logger.info("Taking initial snapshot")
          task = take_snapshot(vm, "initial")
          client.wait_for_task(task)
        end
        result
      end
    end

    def delete_stemcell(stemcell)
      with_thread_name("delete_stemcell(#{stemcell})") do
        pool = Bosh::Director::ThreadPool.new(:min_threads => 1, :max_threads => 32)
        begin
          @resources.datacenters.each_value do |datacenter|
            @logger.info("Looking for stemcell replicas in: #{datacenter.name}")
            templates = client.get_property(datacenter.template_folder, "Folder", "childEntity", :ensure_all => true)
            template_properties = client.get_properties(templates, "VirtualMachine", ["name"])
            template_properties.each do |template, properties|
              template_name = properties["name"].gsub("%2f", "/")
              if template_name.split("/").first.strip == stemcell
                @logger.info("Found: #{template_name}")
                pool.process do
                  @logger.info("Deleting: #{template_name}")
                  client.delete_vm(properties[:obj])
                  @logger.info("Deleted: #{template_name}")
                end
              end
            end
          end
          pool.wait
        ensure
          pool.shutdown
        end
      end
    end

    def create_vm(agent_id, stemcell, resource_pool, networks, disk_locality = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
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
        @logger.info("Creating vm: #{name} on #{cluster.mob} stored in #{datastore.mob}")

        replicated_stemcell_vm = replicate_stemcell(cluster, datastore, stemcell)
        replicated_stemcell_properties = client.get_properties(replicated_stemcell_vm, "VirtualMachine",
                                                          ["config.hardware.device", "snapshot"], :ensure_all => true)
        devices = replicated_stemcell_properties["config.hardware.device"]
        snapshot = replicated_stemcell_properties["snapshot"]

        config = VirtualMachineConfigSpec.new
        config.memoryMB = memory
        config.numCPUs = cpu
        config.deviceChange = []

        system_disk = devices.find {|device| device.kind_of?(VirtualDisk)}
        pci_controller = devices.find {|device| device.kind_of?(VirtualPCIController)}

        file_name = "[#{datastore.name}] #{name}/ephemeral_disk.vmdk"
        ephemeral_disk_config = create_disk_config_spec(datastore.mob, file_name, system_disk.controllerKey, disk,
                                                        :create => true)
        config.deviceChange << ephemeral_disk_config

        dvs_index = {}
        networks.each_value do |network|
          v_network_name = network["cloud_properties"]["name"]
          network_mob = client.find_by_inventory_path([cluster.datacenter.name, "network", v_network_name])
          nic_config = create_nic_config_spec(v_network_name, network_mob, pci_controller.key, dvs_index)
          config.deviceChange << nic_config
        end

        nics = devices.select {|device| device.kind_of?(VirtualEthernetCard)}
        nics.each do |nic|
          nic_config = create_delete_device_spec(nic)
          config.deviceChange << nic_config
        end

        fix_device_unit_numbers(devices, config.deviceChange)

        @logger.info("Cloning vm: #{replicated_stemcell_vm} to #{name}")

        task = clone_vm(replicated_stemcell_vm, name, cluster.datacenter.vm_folder, cluster.resource_pool,
                        :datastore => datastore.mob, :linked => true, :snapshot => snapshot.currentSnapshot,
                        :config => config)
        vm = client.wait_for_task(task)

        vm_properties = client.get_properties(vm, "VirtualMachine", ["config.hardware.device",
                                                                     "config.vAppConfig.property"], :ensure_all => true)
        devices = vm_properties["config.hardware.device"]
        existing_app_properties = vm_properties["config.vAppConfig.property"]
        env = build_agent_env(name, vm, agent_id, system_disk, ephemeral_disk_config.device)
        env["networks"] = build_agent_network_env(devices, networks, dvs_index)
        @logger.info("Setting VM env: #{env.pretty_inspect}")

        vm_config_spec = VirtualMachineConfigSpec.new
        set_agent_env(vm_config_spec, existing_app_properties, env)
        client.reconfig_vm(vm, vm_config_spec)


        @logger.info("Powering on VM: #{vm} (#{name})")
        client.power_on_vm(cluster.datacenter.mob, vm)
        name
      end
    end

    def delete_vm(vm_cid)
      with_thread_name("delete_vm(#{vm_cid})") do
        @logger.info("Deleting vm: #{vm_cid}")
        # TODO: detach any persistent disks
        vm = get_vm_by_cid(vm_cid)

        properties = client.get_properties(vm, "VirtualMachine", ["runtime.powerState", "runtime.question"])

        question = properties["runtime.question"]
        if question
          choices = question.choice
          @logger.info("VM is blocked on a question: #{question.text}, " +
                           "providing default answer: #{choices.choiceInfo[choices.defaultIndex].label}")
          client.answer_vm(vm, question.id, choices.choiceInfo[choices.defaultIndex].key)
          power_state = client.get_property(vm, "VirtualMachine", "runtime.powerState")
        else
          power_state = properties["runtime.powerState"]
        end

        if power_state != VirtualMachinePowerState::PoweredOff
          @logger.info("Powering off vm: #{vm_cid}")
          client.power_off_vm(vm)
        end

        client.delete_vm(vm)
        @logger.info("Deleted vm: #{vm_cid}")
      end
    end

    def configure_networks(vm_cid, networks)
      with_thread_name("configure_networks(#{vm_cid}, ...)") do
        @logger.info("Configuring: #{vm_cid} to use the following network settings: #{networks.pretty_inspect}")
        vm = get_vm_by_cid(vm_cid)
        devices = client.get_property(vm, "VirtualMachine", "config.hardware.device", :ensure_all => true)

        config = VirtualMachineConfigSpec.new
        config.deviceChange = []

        pci_controller = devices.find {|device| device.kind_of?(VirtualPCIController)}

        datacenter = client.find_parent(vm, "Datacenter")
        datacenter_name = client.get_property(datacenter, "Datacenter", "name")

        dvs_index = {}
        networks.each_value do |network|
          v_network_name = network["cloud_properties"]["name"]
          network_mob = client.find_by_inventory_path([datacenter_name, "network", v_network_name])
          nic_config = create_nic_config_spec(v_network_name, network_mob, pci_controller.key, dvs_index)
          config.deviceChange << nic_config
        end

        nics = devices.select {|device| device.kind_of?(VirtualEthernetCard)}
        nics.each do |nic|
          nic_config = create_delete_device_spec(nic)
          config.deviceChange << nic_config
        end

        fix_device_unit_numbers(devices, config.deviceChange)
        @logger.info("Reconfiguring the networks")
        @client.reconfig_vm(vm, config)

        config = VirtualMachineConfigSpec.new
        vm_properties = client.get_properties(vm, "VirtualMachine", ["config.hardware.device",
                                                                     "config.vAppConfig.property"], :ensure_all => true)
        devices = vm_properties["config.hardware.device"]
        existing_app_properties = vm_properties["config.vAppConfig.property"]

        env = get_current_agent_env(existing_app_properties)
        @logger.info("Reading current agent env: #{env.pretty_inspect}")

        env["networks"] = build_agent_network_env(devices, networks, dvs_index)

        @logger.info("Updating agent env to: #{env.pretty_inspect}")
        set_agent_env(config, existing_app_properties, env)

        client.reconfig_vm(vm, config)

        # reboot?
      end
    end

    def attach_disk(vm_cid, disk_cid)
      with_thread_name("attach_disk(#{vm_cid}, #{disk_cid})") do
        @logger.info("Attaching disk: #{disk_cid} on vm: #{vm_cid}")
        disk = Models::Disk[disk_cid]
        raise "Disk not found: #{disk_cid}" if disk.nil?

        vm = get_vm_by_cid(vm_cid)

        datacenter = client.find_parent(vm, "Datacenter")
        datacenter_name = client.get_property(datacenter, "Datacenter", "name")

        vm_properties = client.get_properties(vm, "VirtualMachine", ["datastore", "config.vAppConfig.property",
                                                                     "config.hardware.device"], :ensure_all => true)
        datastores = vm_properties["datastore"]
        raise "Can't find datastore for: #{vm}" if datastores.empty?
        datastore_properties = client.get_properties(datastores, "Datastore", ["name"])

        vm_datastore_by_name = {}
        datastore_properties.each_value { |properties| vm_datastore_by_name[properties["name"]] = properties[:obj] }

        create_disk = false
        if disk.path
          if disk.datacenter == datacenter_name && datastore_properties.has_key?(disk.datastore)
            @logger.info("Disk already in the right datastore")
          else
            @logger.info("Disk needs to move")
            # need to move disk to right datastore
            source_datacenter = client.find_by_inventory_path(disk.datacenter)
            source_path = disk.path
            destination_datastore = datastores.first.first
            datacenter_disk_path = @resources.datacenters[disk.datacenter]
            destination_path = "[#{destination_datastore}] #{datacenter_disk_path}/#{disk.id}.vmdk"
            @logger.info("Moving #{disk.datacenter}/#{source_path} to #{datacenter_name}/#{destination_path}")
            client.move_disk(source_datacenter, source_path, datacenter, destination_path)
            @logger.info("Moved disk successfully")

            disk.datacenter = datacenter_name
            disk.datastore = destination_datastore
            disk.path = destination_path
            disk.save!
          end
        else
          @logger.info("Need to create disk")
          # need to create disk
          disk.datacenter = datacenter_name
          disk.datastore = vm_datastore_by_name.first.first
          datacenter_disk_path = @resources.datacenters[disk.datacenter].disk_path
          disk.path = "[#{disk.datastore}] #{datacenter_disk_path}/#{disk.id}.vmdk"
          disk.save!
          create_disk = true
        end

        devices = vm_properties["config.hardware.device"]

        config = VirtualMachineConfigSpec.new
        config.deviceChange = []

        system_disk = devices.find {|device| device.kind_of?(VirtualDisk)}

        attached_disk_config = create_disk_config_spec(vm_datastore_by_name[disk.datastore], disk.path,
                                                       system_disk.controllerKey, disk.size.to_i,
                                                       :create => create_disk, :independent => true)
        config.deviceChange << attached_disk_config
        fix_device_unit_numbers(devices, config.deviceChange)

        existing_app_properties = vm_properties["config.vAppConfig.property"]
        env = get_current_agent_env(existing_app_properties)
        @logger.info("Reading current agent env: #{env.pretty_inspect}")
        env["disks"]["persistent"][disk.id.to_s] = attached_disk_config.device.unitNumber
        @logger.info("Updating agent env to: #{env.pretty_inspect}")
        set_agent_env(config, existing_app_properties, env)
        @logger.info("Attaching disk")
        client.reconfig_vm(vm, config)
        @logger.info("Finished attaching disk")
        # reboot?
      end
    end

    def detach_disk(vm_cid, disk_cid)
      with_thread_name("detach_disk(#{vm_cid}, #{disk_cid})") do
        @logger.info("Detaching disk: #{disk_cid} from vm: #{vm_cid}")
        disk = Models::Disk[disk_cid]
        raise "Disk not found: #{disk_cid}" if disk.nil?

        vm = get_vm_by_cid(vm_cid)

        vm_properties = client.get_properties(vm, "VirtualMachine", ["config.vAppConfig.property",
                                                                     "config.hardware.device"], :ensure_all => true)

        devices = vm_properties["config.hardware.device"]
        virtual_disk = devices.find { |device| device.kind_of?(VirtualDisk) && device.backing.fileName == disk.path }

        raise "Disk is not attached to this VM" if virtual_disk.nil?

        config = VirtualMachineConfigSpec.new
        config.deviceChange << create_delete_device_spec(virtual_disk)

        existing_app_properties = vm_properties["config.vAppConfig.property"]
        env = get_current_agent_env(existing_app_properties)
        @logger.info("Reading current agent env: #{env.pretty_inspect}")
        env["disks"]["persistent"].delete(disk.id.to_s)
        @logger.info("Updating agent env to: #{env.pretty_inspect}")
        set_agent_env(config, existing_app_properties, env)
        @logger.info("Detaching disk")
        client.reconfig_vm(vm, config)
        @logger.info("Finished detaching disk")
        # reboot?
      end
    end

    def create_disk(size, _ = nil)
      with_thread_name("create_disk(#{size}, _)") do
        @logger.info("Creating disk with size: #{size}")
        disk = Models::Disk.new
        disk.size = size
        disk.save!
        @logger.info("Created disk: #{disk.pretty_inspect}")
        disk.id
      end
    end

    def delete_disk(disk_cid)
      with_thread_name("delete_disk(#{disk_cid})") do
        @logger.info("Deleting disk: #{disk_cid}")
        disk = Models::Disk[disk_cid]
        if disk
          if disk.path
            datacenter = client.find_by_inventory_path(disk.datacenter)
            client.delete_disk(datacenter, disk.path)
          end
          disk.delete
          @logger.info("Finished deleting disk")
        else
          raise "Could not find disk: #{disk_cid}"
        end
      end
    end

    def validate_deployment(old_manifest, new_manifest)
      # TODO: still needed? what does it verify? cloud properties? should be replaced by normalize cloud properties?
    end

    def get_vm_by_cid(vm_cid)
      # TODO: fix when we go to multiple DCs
      datacenter = @resources.datacenters.values.first
      vm = client.find_by_inventory_path([datacenter.name, "vm", datacenter.vm_folder_name, vm_cid])
      raise "VM: #{vm_cid} not found" if vm.nil?
      vm
    end

    def replicate_stemcell(cluster, datastore, stemcell)
      stemcell_vm = client.find_by_inventory_path([cluster.datacenter.name, "vm",
                                                   cluster.datacenter.template_folder_name, stemcell])
      raise "Could not find stemcell: #{stemcell}" if stemcell_vm.nil?
      stemcell_datastore = client.get_property(stemcell_vm, "VirtualMachine", "datastore", :ensure_all => true)

      if stemcell_datastore != datastore.mob
        @logger.info("Stemcell lives on a different datastore, looking for a local copy of: #{stemcell}.")
        local_stemcell_name    = "#{stemcell} / #{datastore.mob}"
        local_stemcell_path    = [cluster.datacenter.name, "vm", cluster.datacenter.template_folder_name,
                                  local_stemcell_name]
        replicated_stemcell_vm = client.find_by_inventory_path(local_stemcell_path)

        if replicated_stemcell_vm.nil?
          @logger.info("Cluster doesn't have stemcell #{stemcell}, replicating")
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
              @logger.info("Replicating #{stemcell} (#{stemcell_vm}) to #{local_stemcell_name}")
              task = clone_vm(stemcell_vm, local_stemcell_name, cluster.datacenter.template_folder,
                              cluster.resource_pool, :datastore => datastore.mob)
              replicated_stemcell_vm = client.wait_for_task(task)
              @logger.info("Replicated #{stemcell} (#{stemcell_vm}) to " +
                               "#{local_stemcell_name} (#{replicated_stemcell_vm})")
              @logger.info("Creating initial snapshot for linked clones on #{replicated_stemcell_vm}")
              task = take_snapshot(replicated_stemcell_vm, "initial")
              client.wait_for_task(task)
              @logger.info("Created initial snapshot for linked clones on #{replicated_stemcell_vm}")
            end
          end
        end
        result = replicated_stemcell_vm
      else
        result = stemcell_vm
      end

      @logger.info("Using stemcell VM: #{result}")

      result
    end

    def build_agent_network_env(devices, networks, dvs_index)
      nics = {}

      devices.each do |device|
        if device.kind_of?(VirtualEthernetCard)
          backing = device.backing
          if backing.kind_of?(VirtualEthernetCardDistributedVirtualPortBackingInfo)
            v_network_name = dvs_index[device.backing.port.portgroupKey]
          else
            v_network_name = device.backing.deviceName
          end
          allocated_networks = nics[v_network_name] || []
          allocated_networks << device
          nics[v_network_name] = allocated_networks
        end
      end

      network_env = {}
      networks.each do |network_name, network|
        network_entry             = network.dup
        v_network_name            = network["cloud_properties"]["name"]
        nic                       = nics[v_network_name].pop
        network_entry["mac"]      = nic.macAddress
        network_env[network_name] = network_entry
      end
      network_env
    end

    def build_agent_env(name, vm, agent_id, system_disk, ephemeral_disk)
      disk_env = {
        "system" => system_disk.unitNumber,
        "ephemeral" => ephemeral_disk.unitNumber,
        "persistent" => {}
      }

      vm_env = {
        "name" => name,
        "id" => vm
      }

      env = {}
      env["vm"] = vm_env
      env["agent_id"] = agent_id
      env["disks"] = disk_env
      env.merge!(@agent_properties)
      env
    end

    def get_current_agent_env(existing_app_properties)
      property = existing_app_properties.find { |property_info| property_info.id == BOSH_AGENT_PROPERTIES_ID }
      property ? Yajl::Parser.parse(property.value) : nil
    end

    def set_agent_env(vm_config_spec, existing_app_properties, env)
      # TODO: scan vm_config_spec for new properties being added when calculating max_key, otherwise it will only allow
      # one property per reconfig

      max_key = -1
      existing_property = nil
      existing_app_properties.each do |property_info|
        if property_info.id == BOSH_AGENT_PROPERTIES_ID
          existing_property = property_info
          break
        end
        max_key = property_info.key if property_info.key > max_key
      end

      if existing_property
        operation = :edit
        key = existing_property.key
      else
        operation = :add
        key = max_key + 1
      end

      env_json = Yajl::Encoder.encode(env)
      env_property = create_app_property_spec(key, BOSH_AGENT_PROPERTIES_ID, "string",
                                              env_json, operation)

      app_config_spec = VmConfigSpec.new
      app_config_spec.property = [env_property]
      # make sure the transport is set correctly, needed for guest to access these properties
      app_config_spec.ovfEnvironmentTransport = ["iso", "com.vmware.guestInfo"]

      vm_config_spec.vAppConfig = app_config_spec

      extra_config = OptionValue.new
      extra_config.key = "guestinfo.bosh"

      # need to manually create SOAPElement to work around anyType encoding bug
      value = SOAP::SOAPElement.new(XSD::QName.new(VSphereCloud::DefaultMappingRegistry::NsVim25, "value"), env_json)
      value.extraattr[XSD::AttrTypeName] = XSD::XSDString::Type

      extra_config.value = value
      vm_config_spec.extraConfig = [extra_config]
    end

    def clone_vm(vm, name, folder, resource_pool, options={})
      relocation_spec = VirtualMachineRelocateSpec.new
      relocation_spec.datastore = options[:datastore] if options[:datastore]
      if options[:linked]
        relocation_spec.diskMoveType = VirtualMachineRelocateDiskMoveOptions::CreateNewChildDiskBacking
      end
      relocation_spec.pool = resource_pool

      clone_spec = VirtualMachineCloneSpec.new
      clone_spec.config = options[:config] if options[:config]
      clone_spec.location = relocation_spec
      clone_spec.powerOn = options[:power_on] ? true : false
      clone_spec.snapshot = options[:snapshot] if options[:snapshot]
      clone_spec.template = false

      client.service.cloneVM_Task(CloneVMRequestType.new(vm, folder, name,
                                                                                  clone_spec)).returnval
    end

    def take_snapshot(vm, name)
      request = CreateSnapshotRequestType.new(vm)
      request.name = name
      request.memory = false
      request.quiesce = false
      client.service.createSnapshot_Task(request).returnval
    end

    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
    end

    def create_disk_config_spec(datastore, file_name, controller_key, space, options = {})
      backing_info = VirtualDiskFlatVer2BackingInfo.new
      backing_info.datastore = datastore
      backing_info.diskMode = options[:independent] ?
                              VirtualDiskMode::Independent_persistent : VirtualDiskMode::Persistent
      backing_info.fileName = file_name

      virtual_disk = VirtualDisk.new
      virtual_disk.key = -1
      virtual_disk.controllerKey = controller_key
      virtual_disk.backing = backing_info
      virtual_disk.capacityInKB = space * 1024

      device_config_spec = VirtualDeviceConfigSpec.new
      device_config_spec.device = virtual_disk
      device_config_spec.operation = VirtualDeviceConfigSpecOperation::Add
      if options[:create]
        device_config_spec.fileOperation = VirtualDeviceConfigSpecFileOperation::Create
      end
      device_config_spec
    end

    def create_nic_config_spec(v_network_name, network, controller_key, dvs_index)
      if network.xmlattr_type == "DistributedVirtualPortgroup"
        portgroup_properties = client.get_properties(network, "DistributedVirtualPortgroup",
                                                     ["config.key", "config.distributedVirtualSwitch"],
                                                     :ensure_all => true)

        switch = portgroup_properties["config.distributedVirtualSwitch"]
        switch_uuid = client.get_property(switch, "DistributedVirtualSwitch", "uuid", :ensure_all => true)

        port = DistributedVirtualSwitchPortConnection.new
        port.switchUuid = switch_uuid
        port.portgroupKey = portgroup_properties["config.key"]

        backing_info = VirtualEthernetCardDistributedVirtualPortBackingInfo.new
        backing_info.port = port

        dvs_index[port.portgroupKey] = v_network_name
      else
        backing_info = VirtualEthernetCardNetworkBackingInfo.new
        backing_info.deviceName = v_network_name
        backing_info.network = network
      end

      nic = VirtualVmxnet3.new
      nic.key = -1
      nic.controllerKey = controller_key
      nic.backing = backing_info

      device_config_spec = VirtualDeviceConfigSpec.new
      device_config_spec.device = nic
      device_config_spec.operation = VirtualDeviceConfigSpecOperation::Add
      device_config_spec
    end

    def create_delete_device_spec(device, options = {})
      device_config_spec = VirtualDeviceConfigSpec.new
      device_config_spec.device = device
      device_config_spec.operation = VirtualDeviceConfigSpecOperation::Remove
      if options[:destroy]
        device_config_spec.fileOperation = VirtualDeviceConfigSpecFileOperation::Destroy
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

    def create_app_property_spec(key, id, type, value, operation)
      property_info = VAppPropertyInfo.new
      property_info.key = key
      property_info.id = id
      property_info.type = type
      property_info.value = value

      property_spec = VAppPropertySpec.new
      property_spec.operation = operation == :add ? ArrayUpdateOperation::Add : ArrayUpdateOperation::Edit
      property_spec.info = property_info
      property_spec
    end

    def import_ovf(name, ovf, resource_pool, datastore)
      import_spec_params = OvfCreateImportSpecParams.new
      import_spec_params.entityName = name
      import_spec_params.locale = 'US'
      import_spec_params.deploymentOption = ''

      ovf_file = File.open(ovf)
      ovf_descriptor = ovf_file.read
      ovf_file.close

      request = CreateImportSpecRequestType.new(
              client.service_content.ovfManager, ovf_descriptor, resource_pool, datastore, import_spec_params)
      client.service.createImportSpec(request).returnval
    end

    def obtain_nfc_lease(resource_pool, import_spec, folder)
      request = ImportVAppRequestType.new(resource_pool, import_spec, folder)
      client.service.importVApp(request).returnval
    end

    def wait_for_nfc_lease(lease)
      loop do
        state = client.get_property(lease, 'HttpNfcLease', 'state')
        unless state == HttpNfcLeaseState::Initializing
          return state
        end
        sleep(1.0)
      end
    end

    def upload_ovf(ovf, lease, file_items)
      info = client.get_property(lease, 'HttpNfcLease', 'info', :ensure_all => true)
      lease_updater = LeaseUpdater.new(client, lease)

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

            @logger.info("Uploading disk to: #{device_url.url}")

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
      pool = Bosh::Director::ThreadPool.new(:min_threads => 1, :max_threads => 32)

      begin
        index = 0

        @resources.datacenters.each_value do |datacenter|
          vm_folder_path = [datacenter.name, "vm", datacenter.vm_folder_name]
          vm_folder = client.find_by_inventory_path(vm_folder_path)
          vms = client.get_managed_objects("VirtualMachine", :root => vm_folder)
          next if vms.empty?

          vm_properties = client.get_properties(vms, "VirtualMachine", ["name"])

          vm_properties.each do |_, properties|
            pool.process do
              @lock.synchronize {index += 1}
              vm = properties["name"]
              @logger.debug("Deleting #{index}/#{vms.size}: #{vm}")
              begin
                delete_vm(vm)
              rescue Exception => e
                @logger.info("#{e} - #{e.backtrace.join("\n")}")
              end
            end
          end
        end

        pool.wait
      ensure
        pool.shutdown
      end
    end

  end
end