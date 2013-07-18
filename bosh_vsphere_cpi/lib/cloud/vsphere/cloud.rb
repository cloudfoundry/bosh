require "membrane"
require "ruby_vim_sdk"

require "cloud/vsphere/client"
require "cloud/vsphere/config"
require "cloud/vsphere/lease_updater"
require "cloud/vsphere/resources"
require "cloud/vsphere/resources/cluster"
require "cloud/vsphere/resources/datacenter"
require "cloud/vsphere/resources/datastore"
require "cloud/vsphere/resources/folder"
require "cloud/vsphere/resources/resource_pool"
require "cloud/vsphere/resources/scorer"
require "cloud/vsphere/resources/util"
require "cloud/vsphere/models/disk"
require "cloud/vsphere/vm_configurable"
require "cloud/vsphere/stemcell_manager"

module VSphereCloud
  class Cloud < Bosh::Cloud
    include VimSdk
    include VmConfigurable

    class TimeoutException < StandardError; end

    attr_accessor :client

    def initialize(options)
      Config.configure(options)

      @logger = Config.logger
      @client = Config.client
      @rest_client = Config.rest_client
      @resources = Resources.new

      # Global lock
      @lock = Mutex.new

      # Resource locks
      @locks = {}
      @locks_mutex = Mutex.new

      # We get disconnected if the connection is inactive for a long period.
      Thread.new do
        while true do
          sleep(60)
          @client.service_instance.current_time
        end
      end

      setup_at_exit
    end

    def setup_at_exit
      # HACK: finalizer not getting called, so we'll rely on at_exit
      at_exit { @client.logout }
    end

    def has_vm?(vm_cid)
      get_vm_by_cid(vm_cid)
      true
    rescue Bosh::Clouds::VMNotFound
      false
    end

    def stemcell_manager
      @stemcell ||= StemcellManager.new(@client, @logger, @resources)
    end

    def create_stemcell(image, _)
       with_thread_name("create_stemcell(#{image}, _)") do
         "sc-#{generate_unique_name}".tap do |name|
            Dir.mktmpdir { |temp_dir| vm = stemcell_manager.create(image, name, temp_dir) }
            @logger.info("Taking initial snapshot")
            @client.wait_for_task(take_snapshot(vm, "initial"))
          end
       end
     end

    def delete_stemcell(stemcell)
      with_thread_name("delete_stemcell(#{stemcell})") do
        stemcell_manager.delete(stemcell)
      end
    end

    def create_vm(agent_id, stemcell_name, resource_pool, networks, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        memory = resource_pool["ram"]
        disk = resource_pool["disk"]
        cpu = resource_pool["cpu"]
        name = "vm-#{generate_unique_name}"

        @logger.info("Validating requested number of vCPUs is a power of 2")
        raise "Number of vCPUs: #{cpu} is not a power of 2." unless cpu & cpu - 1 == 0

        @logger.info("Finding stemcell VM: #{stemcell_name}")
        stemcell_vm = find_stemcell_vm!(stemcell_name)

        @logger.info("Finding cluster and datastore to accommodate VM")
        cluster, datastore = place_vm(stemcell_vm, memory, disk, disk_locality)
        @logger.info("Creating VM: #{name} on #{cluster.mob} stored in #{datastore.mob}")

        @logger.info("Replicating stemcell VM")
        replicated_stemcell_vm = replicate_stemcell(cluster, datastore, stemcell_name)
        replicated_stemcell_properties = client.get_properties(
          replicated_stemcell_vm, 
          Vim::VirtualMachine,
          ["config.hardware.device", "snapshot"],
          ensure_all: true
        )
        devices = replicated_stemcell_properties["config.hardware.device"]
        system_disk = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualDisk) }

        @logger.info("Prepare initial reconfiguration of VM devices")
        ephemeral_disk_config = create_disk_config_spec(
          datastore.mob, 
          "[#{datastore.name}] #{name}/ephemeral_disk.vmdk",
          system_disk.controller_key, 
          disk,
          create: true
        )
        config = Vim::Vm::ConfigSpec.new(memory_mb: memory, num_cpus: cpu)
        dvs_index = {}
        config.device_change = [ephemeral_disk_config] + nic_configs(devices, cluster, dvs_index) + nic_deletion_configs(devices)
        fix_device_unit_numbers(devices, config.device_change)

        @logger.info("Cloning from replicated stemcell to VM with initial device changes: #{replicated_stemcell_vm} to #{name}")
        task = clone_vm(
          replicated_stemcell_vm,
          name,
          cluster.datacenter.vm_folder.mob,
          cluster.resource_pool.mob,
          datastore: datastore.mob, linked: true, snapshot: replicated_stemcell_properties["snapshot"].current_snapshot, config: config
        )
        vm = client.wait_for_task(task)

        @logger.info("Configuring cloned VM")
        begin
          devices = client.get_properties(
            vm,
            Vim::VirtualMachine,
            ["config.hardware.device"],
            ensure_all: true
          )["config.hardware.device"]

          @logger.info("Uploading blank environment ISO file and reconfiguring VM with CDROM for ISO file")
          prepare_vm_for_env_data(vm, cluster.datacenter.name, datastore.name, vm_name)

          @logger.info("Generating environment data") 
          network_env = generate_network_env(devices, networks, dvs_index)
          disk_env = generate_disk_env(system_disk, ephemeral_disk_config.device)
          env = generate_agent_env(name, vm, agent_id, network_env, disk_env)
          env["env"] = environment
          
          @logger.info("Setting VM env: #{env.pretty_inspect}")
          set_agent_env(vm, { datacenter: cluster.datacenter.name, datastore: datastore.name, vm: name }, env)

          @logger.info("Powering on VM: #{vm} (#{name})")
          client.power_on_vm(cluster.datacenter.mob, vm)

        rescue => e

          @logger.info("#{e} - #{e.backtrace.join("\n")}")
          delete_vm(name)
          raise e
        end

        name
      end
    end

    def retry_block(num = 2)
      result = nil
      num.times do |i|
        begin
          result = yield
          break
        rescue RuntimeError
          raise if i + 1  >= num
        end
      end
      result
    end

    def delete_vm(vm_cid)
      with_thread_name("delete_vm(#{vm_cid})") do
        @logger.info("Deleting vm: #{vm_cid}")

        vm = get_vm_by_cid(vm_cid)
        datacenter = client.find_parent(vm, Vim::Datacenter)
        properties = client.get_properties(vm, Vim::VirtualMachine, ["runtime.powerState", "runtime.question",
                                                                     "config.hardware.device", "name"],
                                           ensure: ["config.hardware.device"])

        retry_block do
          question = properties["runtime.question"]
          if question
            choices = question.choice
            @logger.info("VM is blocked on a question: #{question.text}, " +
                         "providing default answer: #{choices.choice_info[choices.default_index].label}")
            client.answer_vm(vm, question.id, choices.choice_info[choices.default_index].key)
            power_state = client.get_property(vm, Vim::VirtualMachine, "runtime.powerState")
          else
            power_state = properties["runtime.powerState"]
          end

          if power_state != Vim::VirtualMachine::PowerState::POWERED_OFF
            @logger.info("Powering off vm: #{vm_cid}")
            client.power_off_vm(vm)
          end
        end

        # Detach any persistent disks in case they were not detached from the instance
        devices = properties["config.hardware.device"]
        persistent_disks = devices.select { |device| device.kind_of?(Vim::Vm::Device::VirtualDisk) &&
            device.backing.disk_mode == Vim::Vm::Device::VirtualDiskOption::DiskMode::INDEPENDENT_PERSISTENT }

        unless persistent_disks.empty?
          @logger.info("Found #{persistent_disks.size} persistent disk(s)")
          config = Vim::Vm::ConfigSpec.new
          config.device_change = []
          persistent_disks.each do |virtual_disk|
            @logger.info("Detaching: #{virtual_disk.backing.file_name}")
            config.device_change << create_delete_device_spec(virtual_disk)
          end
          retry_block { client.reconfig_vm(vm, config) }
          @logger.info("Detached #{persistent_disks.size} persistent disk(s)")
        end

        retry_block { client.delete_vm(vm) }
        @logger.info("Deleted vm: #{vm_cid}")

        # Delete env.iso and VM specific files managed by the director
        retry_block do
          datastore = get_primary_datastore(devices)
          datastore_name = client.get_property(datastore, Vim::Datastore, "name")
          vm_name = properties["name"]
          client.delete_path(datacenter, "[#{datastore_name}] #{vm_name}")
        end
      end
    end

    def reboot_vm(vm_cid)
      with_thread_name("reboot_vm(#{vm_cid})") do
        vm = get_vm_by_cid(vm_cid)
        datacenter = client.find_parent(vm, Vim::Datacenter)
        power_state = client.get_property(vm, Vim::VirtualMachine, "runtime.powerState")

        @logger.info("Reboot vm = #{vm_cid}")
        if power_state != Vim::VirtualMachine::PowerState::POWERED_ON
          @logger.info("VM not in POWERED_ON state. Current state : #{power_state}")
        end
        begin
          vm.reboot_guest
        rescue => e
          @logger.error("Soft reboot failed #{e} -#{e.backtrace.join("\n")}")
          @logger.info("Try hard reboot")
          # if we fail to perform a soft-reboot we force a hard-reboot
          if power_state == Vim::VirtualMachine::PowerState::POWERED_ON
            retry_block { client.power_off_vm(vm) }
          end
          retry_block { client.power_on_vm(datacenter, vm) }
        end
      end
    end

    def set_vm_metadata(vm_cid, metadata)
      with_thread_name("set_vm_metadata(#{vm_cid}, ...)") do
        begin
          fields_manager = client.service_content.custom_fields_manager
          custom_fields = fields_manager.field
          name_to_key_id = {}

          metadata.each_key do |name|
            field = custom_fields.find { |field| field.name == name.to_s &&
                field.managed_object_type == Vim::VirtualMachine }
            unless field
              field = fields_manager.add_field_definition(
                  name.to_s, Vim::VirtualMachine, nil, nil)
            end
            name_to_key_id[name] = field.key
          end

          vm = get_vm_by_cid(vm_cid)

          metadata.each do |name, value|
            value = "" if value.nil? # value is required
            fields_manager.set_field(vm, name_to_key_id[name], value)
          end
        rescue SoapException => e
          if e.fault.kind_of?(Vim::Fault::NoPermission)
            @logger.warn("Can't set custom fields due to lack of " +
                             "permission: #{e.message}")
          else
            raise e
          end
        end
      end
    end

    def configure_networks(vm_cid, networks)
      with_thread_name("configure_networks(#{vm_cid}, ...)") do
        vm = get_vm_by_cid(vm_cid)

        @logger.debug("Waiting for the VM to shutdown")
        state = :initial
        begin
          wait_until_off(vm, 30)
        rescue TimeoutException
          case state
            when :initial
              @logger.debug("The guest did not shutdown in time, requesting it to shutdown")
              begin
                vm.shutdown_guest
              rescue => e
                @logger.debug("Ignoring possible race condition when a VM has " +
                              "powered off by the time we ask it to shutdown: #{e.message}")
              end
              state = :shutdown_guest
              retry
            else
              @logger.error("The guest did not shutdown in time, even after a request")
              raise
          end
        end

        @logger.info("Configuring: #{vm_cid} to use the following network settings: #{networks.pretty_inspect}")
        vm = get_vm_by_cid(vm_cid)
        devices = client.get_property(vm, Vim::VirtualMachine, "config.hardware.device", ensure_all: true)
        datacenter = client.find_parent(vm, Vim::Datacenter)
        datacenter_name = client.get_property(datacenter, Vim::Datacenter, "name")
        pci_controller = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualPCIController) }

        config = Vim::Vm::ConfigSpec.new
        config.device_change = []
        nics = devices.select { |device| device.kind_of?(Vim::Vm::Device::VirtualEthernetCard) }
        nics.each do |nic|
          nic_config = create_delete_device_spec(nic)
          config.device_change << nic_config
        end

        dvs_index = {}
        networks.each_value do |network|
          v_network_name = network["cloud_properties"]["name"]
          network_mob = client.find_by_inventory_path([datacenter_name, "network", v_network_name])
          nic_config = create_nic_config_spec(v_network_name, network_mob, pci_controller.key, dvs_index)
          config.device_change << nic_config
        end

        fix_device_unit_numbers(devices, config.device_change)
        @logger.debug("Reconfiguring the networks")
        @client.reconfig_vm(vm, config)

        location = get_vm_location(vm, datacenter: datacenter_name)
        env = get_current_agent_env(location)
        @logger.debug("Reading current agent env: #{env.pretty_inspect}")

        devices = client.get_property(vm, Vim::VirtualMachine, "config.hardware.device", ensure_all: true)
        env["networks"] = generate_network_env(devices, networks, dvs_index)

        @logger.debug("Updating agent env to: #{env.pretty_inspect}")
        set_agent_env(vm, location, env)

        @logger.debug("Powering the VM back on")
        client.power_on_vm(datacenter, vm)
      end
    end

    def get_vm_host_info(vm_ref)
      vm = @client.get_properties(vm_ref, Vim::VirtualMachine, "runtime")
      vm_runtime = vm["runtime"]

      properties = @client.get_properties(vm_runtime.host, Vim::HostSystem, ["datastore", "parent"],
                                          ensure_all: true)

      # Get the cluster that the vm's host belongs to.
      cluster = @client.get_properties(properties["parent"], Vim::ClusterComputeResource, "name")

      # Get the datastores that are accessible to the vm's host.
      datastores = properties["datastore"].map { |store|
        @client.get_properties(store, Vim::Datastore, "info", ensure_all: true)["info"].name
      }

      {"cluster" => cluster["name"], "datastores" => datastores}
    end

    def find_persistent_datastore(datacenter_name, host_info, disk_size)
      @resources.place_persistent_datastore(datacenter_name, host_info["cluster"], disk_size).tap do |ds|
        raise Bosh::Clouds::NoDiskSpace.new(true), "Not enough persistent space " +
          "on cluster #{host_info["cluster"]}, #{disk_size}" if ds.nil?

        # Sanity check, verify that the vm's host can access this datastore
        raise "Datastore not accessible to host, #{ds.name}, #{host_info["datastores"]}" \
          unless host_inf["datastores"].include?(ds.name)
      end
    end

    def attach_disk(vm_cid, disk_cid)
      with_thread_name("attach_disk(#{vm_cid}, #{disk_cid})") do
        @logger.info("Attaching disk: #{disk_cid} on vm: #{vm_cid}")
        disk = Models::Disk.first(uuid: disk_cid)
        raise "Disk not found: #{disk_cid}" if disk.nil?

        vm = get_vm_by_cid(vm_cid)

        datacenter = client.find_parent(vm, Vim::Datacenter)
        datacenter_name = client.get_property(datacenter, Vim::Datacenter, "name")

        vm_properties = client.get_properties(vm, Vim::VirtualMachine, "config.hardware.device", ensure_all: true)
        host_info = get_vm_host_info(vm)

        create_disk = false
        if disk.path
          if disk.datacenter == datacenter_name &&
                  @resources.validate_persistent_datastore(datacenter_name, disk.datastore) &&
                  host_info["datastores"].include?(disk.datastore)
            @logger.info("Disk already in the right datastore #{datacenter_name} #{disk.datastore}")
            persistent_datastore = @resources.persistent_datastore(
                datacenter_name, host_info["cluster"], disk.datastore)
            @logger.debug("Datastore: #{persistent_datastore}")
          else
            @logger.info("Disk needs to move from #{datacenter_name} #{disk.datastore}")
            # Find the destination datastore
            persistent_datastore = find_persistent_datastore(datacenter_name, host_info, disk.size)

            # Need to move disk to right datastore
            source_datacenter = client.find_by_inventory_path(disk.datacenter)
            source_path = disk.path
            datacenter_disk_path = @resources.datacenters[disk.datacenter].disk_path

            destination_path = "[#{persistent_datastore.name}] #{datacenter_disk_path}/#{disk.uuid}"
            @logger.info("Moving #{disk.datacenter}/#{source_path} to #{datacenter_name}/#{destination_path}")

            if Config.copy_disks
              client.copy_disk(source_datacenter, source_path, datacenter, destination_path)
              @logger.info("Copied disk successfully")
            else
              client.move_disk(source_datacenter, source_path, datacenter, destination_path)
              @logger.info("Moved disk successfully")
            end

            disk.datacenter = datacenter_name
            disk.datastore = persistent_datastore.name
            disk.path = destination_path
            disk.save
          end
        else
          @logger.info("Need to create disk")

          # Find the destination datastore
          persistent_datastore = find_persistent_datastore(datacenter_name, host_info, disk.size)

          # Need to create disk
          disk.datacenter = datacenter_name
          disk.datastore = persistent_datastore.name
          datacenter_disk_path = @resources.datacenters[disk.datacenter].disk_path
          disk.path = "[#{disk.datastore}] #{datacenter_disk_path}/#{disk.uuid}"
          disk.save
          create_disk = true
        end

        devices = vm_properties["config.hardware.device"]
        system_disk = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualDisk) }

        vmdk_path = "#{disk.path}.vmdk"
        attached_disk_config = create_disk_config_spec(persistent_datastore.mob, vmdk_path,
                                                       system_disk.controller_key, disk.size.to_i,
                                                       create: create_disk, independent: true)
        config = Vim::Vm::ConfigSpec.new
        config.device_change = []
        config.device_change << attached_disk_config
        fix_device_unit_numbers(devices, config.device_change)

        location = get_vm_location(vm, datacenter: datacenter_name)
        env = get_current_agent_env(location)
        @logger.info("Reading current agent env: #{env.pretty_inspect}")
        env["disks"]["persistent"][disk.uuid] = attached_disk_config.device.unit_number
        @logger.info("Updating agent env to: #{env.pretty_inspect}")
        set_agent_env(vm, location, env)
        @logger.info("Attaching disk")
        client.reconfig_vm(vm, config)
        @logger.info("Finished attaching disk")
      end
    end

    def detach_disk(vm_cid, disk_cid)
      with_thread_name("detach_disk(#{vm_cid}, #{disk_cid})") do
        @logger.info("Detaching disk: #{disk_cid} from vm: #{vm_cid}")
        disk = Models::Disk.first(uuid: disk_cid)
        raise "Disk not found: #{disk_cid}" if disk.nil?

        vm = get_vm_by_cid(vm_cid)

        devices = client.get_property(vm, Vim::VirtualMachine, "config.hardware.device", ensure_all: true)

        vmdk_path = "#{disk.path}.vmdk"
        virtual_disk = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualDisk) &&
            device.backing.file_name == vmdk_path }
        raise Bosh::Clouds::DiskNotAttached.new(true), "Disk (#{disk_cid}) is not attached to VM (#{vm_cid})" if virtual_disk.nil?

        config = Vim::Vm::ConfigSpec.new
        config.device_change = []
        config.device_change << create_delete_device_spec(virtual_disk)

        location = get_vm_location(vm)
        env = get_current_agent_env(location)
        @logger.info("Reading current agent env: #{env.pretty_inspect}")
        env["disks"]["persistent"].delete(disk.uuid)
        @logger.info("Updating agent env to: #{env.pretty_inspect}")
        set_agent_env(vm, location, env)
        @logger.info("Detaching disk")
        client.reconfig_vm(vm, config)

        # detach-disk is async and task completion does not necessarily mean
        # that changes have been applied to VC side. Query VC until we confirm
        # that the change has been applied. This is a known issue for vsphere 4.
        # Fixed in vsphere 5.
        5.times do
          devices = client.get_property(vm, Vim::VirtualMachine, "config.hardware.device", ensure_all: true)
          virtual_disk = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualDisk) &&
            device.backing.file_name == vmdk_path }
          break if virtual_disk.nil?
          sleep(1.0)
        end
        raise "Failed to detach disk: #{disk_cid} from vm: #{vm_cid}" unless virtual_disk.nil?

        @logger.info("Finished detaching disk")
      end
    end

    def create_disk(size, _ = nil)
      with_thread_name("create_disk(#{size}, _)") do
        @logger.info("Creating disk with size: #{size}")
        disk = Models::Disk.new
        disk.uuid = "disk-#{generate_unique_name}"
        disk.size = size
        disk.save
        @logger.info("Created disk: #{disk.inspect}")
        disk.uuid
      end
    end

    def delete_disk(disk_cid)
      with_thread_name("delete_disk(#{disk_cid})") do
        @logger.info("Deleting disk: #{disk_cid}")
        disk = Models::Disk.first(uuid: disk_cid)
        if disk
          if disk.path
            datacenter = client.find_by_inventory_path(disk.datacenter)
            raise Bosh::Clouds::DiskNotFound.new(true), "disk #{disk_cid} not found" if datacenter.nil? || disk.path.nil?

            client.delete_disk(datacenter, disk.path)
          end
          disk.destroy
          @logger.info("Finished deleting disk")
        else
          raise "Could not find disk: #{disk_cid}"
        end
      end
    end

    def validate_deployment(old_manifest, new_manifest)
    end

    def get_vm_by_cid(vm_cid)
      @resources.datacenters.each_value do |datacenter|
        vm = client.find_by_inventory_path(
            [datacenter.name, "vm", datacenter.vm_folder.name, vm_cid])
        unless vm.nil?
          return vm
        end
      end
      raise Bosh::Clouds::VMNotFound, "VM `#{vm_cid}' not found"
    end

    def replicate_stemcell(cluster, datastore, stemcell)
      stemcell_vm = client.find_by_inventory_path([cluster.datacenter.name, "vm",
                                                   cluster.datacenter.template_folder.name, stemcell])
      raise "Could not find stemcell: #{stemcell}" if stemcell_vm.nil?
      stemcell_datastore = client.get_property(stemcell_vm, Vim::VirtualMachine, "datastore", ensure_all: true)

      if stemcell_datastore != datastore.mob
        @logger.info("Stemcell lives on a different datastore, looking for a local copy of: #{stemcell}.")
        local_stemcell_name    = "#{stemcell} / #{datastore.mob.__mo_id__}"
        local_stemcell_path    = [cluster.datacenter.name, "vm", cluster.datacenter.template_folder.name,
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
              task = clone_vm(stemcell_vm, local_stemcell_name, cluster.datacenter.template_folder.mob,
                              cluster.resource_pool.mob, datastore: datastore.mob)
              replicated_stemcell_vm = client.wait_for_task(task)
              @logger.info("Replicated #{stemcell} (#{stemcell_vm}) to " +
                               "#{local_stemcell_name} (#{replicated_stemcell_vm})")
              @logger.info("Creating initial snapshot for linked clones on #{replicated_stemcell_vm}")
              task = take_snapshot(replicated_stemcell_vm, "initial")
              client.wait_for_task(task)
              @logger.info("Created initial snapshot for linked clones on #{replicated_stemcell_vm}")
            end
          end
        else
          @logger.info("Found local stemcell replica: #{replicated_stemcell_vm}")
        end
        result = replicated_stemcell_vm
      else
        @logger.info("Stemcell was already local: #{stemcell_vm}")
        result = stemcell_vm
      end

      @logger.info("Using stemcell VM: #{result}")

      result
    end

    def generate_network_env(devices, networks, dvs_index)
      nics = {}

      devices.each do |device|
        if device.kind_of?(Vim::Vm::Device::VirtualEthernetCard)
          backing = device.backing
          if backing.kind_of?(Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo)
            v_network_name = dvs_index[device.backing.port.portgroup_key]
          else
            v_network_name = device.backing.device_name
          end
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
        network_entry["mac"] = nic.mac_address
        network_env[network_name] = network_entry
      end
      network_env
    end

    def generate_disk_env(system_disk, ephemeral_disk)
      {
        "system" => system_disk.unit_number,
        "ephemeral" => ephemeral_disk.unit_number,
        "persistent" => {}
      }
    end

    def generate_agent_env(name, vm, agent_id, networking_env, disk_env)
      vm_env = {
        "name" => name,
        "id" => vm.__mo_id__
      }

      env = {}
      env["vm"] = vm_env
      env["agent_id"] = agent_id
      env["networks"] = networking_env
      env["disks"] = disk_env
      env.merge!(Config.agent)
      env
    end

    def get_vm_location(vm, options = {})
      datacenter_name = options[:datacenter]
      datastore_name = options[:datastore]
      vm_name = options[:vm]

      unless datacenter_name
        datacenter = client.find_parent(vm, Vim::Datacenter)
        datacenter_name = client.get_property(datacenter, Vim::Datacenter, "name")
      end

      if vm_name.nil? || datastore_name.nil?
        vm_properties = client.get_properties(vm, Vim::VirtualMachine, ["config.hardware.device", "name"],
                                              ensure_all: true)
        vm_name = vm_properties["name"]

        unless datastore_name
          devices = vm_properties["config.hardware.device"]
          datastore = get_primary_datastore(devices)
          datastore_name = client.get_property(datastore, Vim::Datastore, "name")
        end
      end

      {datacenter: datacenter_name, datastore: datastore_name, vm: vm_name}
    end

    def get_primary_datastore(devices)
      ephemeral_disks = devices.select { |device| device.kind_of?(Vim::Vm::Device::VirtualDisk) &&
          device.backing.disk_mode != Vim::Vm::Device::VirtualDiskOption::DiskMode::INDEPENDENT_PERSISTENT }

      datastore = nil
      ephemeral_disks.each do |disk|
        if datastore
          raise "Ephemeral disks should all be on the same datastore." unless datastore.eql?(disk.backing.datastore)
        else
          datastore = disk.backing.datastore
        end
      end

      datastore
    end

    def get_current_agent_env(location)
      contents = fetch_file(location[:datacenter], location[:datastore], "#{location[:vm]}/env.json")
      contents ? Yajl::Parser.parse(contents) : nil
    end

    def set_agent_env(vm, location, env)
      env_json = Yajl::Encoder.encode(env)

      connect_cdrom(vm, false)
      upload_file(location[:datacenter], location[:datastore], "#{location[:vm]}/env.json", env_json)
      upload_file(location[:datacenter], location[:datastore], "#{location[:vm]}/env.iso", generate_env_iso(env_json))
      connect_cdrom(vm, true)
    end

    def connect_cdrom(vm, connected = true)
      devices = client.get_property(vm, Vim::VirtualMachine, "config.hardware.device", ensure_all: true)
      cdrom = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualCdrom) }

      if cdrom.connectable.connected != connected
        cdrom.connectable.connected = connected
        config = Vim::Vm::ConfigSpec.new
        config.device_change = [create_edit_device_spec(cdrom)]
        client.reconfig_vm(vm, config)
      end
    end

    def configure_env_cdrom(datastore, devices, file_name)
      backing_info = Vim::Vm::Device::VirtualCdrom::IsoBackingInfo.new
      backing_info.datastore = datastore
      backing_info.file_name = file_name

      connect_info = Vim::Vm::Device::VirtualDevice::ConnectInfo.new
      connect_info.allow_guest_control = false
      connect_info.start_connected = true
      connect_info.connected = true

      cdrom = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualCdrom) }
      cdrom.connectable = connect_info
      cdrom.backing = backing_info

      create_edit_device_spec(cdrom)
    end

    def which(programs)
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        programs.each do |bin|
          exe = File.join(path, bin)
          return exe if File.exists?(exe)
        end
      end
      programs.first
    end

    def genisoimage
      @genisoimage ||= which(%w{genisoimage mkisofs})
    end

    def generate_env_iso(env)
      Dir.mktmpdir do |path|
        env_path = File.join(path, "env")
        iso_path = File.join(path, "env.iso")
        File.open(env_path, "w") { |f| f.write(env) }
        output = `#{genisoimage} -o #{iso_path} #{env_path} 2>&1`
        raise "#{$?.exitstatus} -#{output}" if $?.exitstatus != 0
        File.open(iso_path, "r") { |f| f.read }
      end
    end

    def clone_vm(vm, name, folder, resource_pool, options={})
      relocation_spec =Vim::Vm::RelocateSpec.new
      relocation_spec.datastore = options[:datastore] if options[:datastore]
      if options[:linked]
        relocation_spec.disk_move_type = Vim::Vm::RelocateSpec::DiskMoveOptions::CREATE_NEW_CHILD_DISK_BACKING
      end
      relocation_spec.pool = resource_pool

      clone_spec = Vim::Vm::CloneSpec.new
      clone_spec.config = options[:config] if options[:config]
      clone_spec.location = relocation_spec
      clone_spec.power_on = options[:power_on] ? true : false
      clone_spec.snapshot = options[:snapshot] if options[:snapshot]
      clone_spec.template = false

      vm.clone(folder, name, clone_spec)
    end

    def generate_unique_name
      SecureRandom.uuid
    end

    def fix_device_unit_numbers(devices, device_changes)
      grouped_devices = devices.group_by(&:controller_key)

      next_unit_numbers = grouped_devices.inject({}) do |memo, (key, devices)|
        memo[key] = devices.map(&:unit_number).max + 1
      end

      unnumbered_devices = device_changes.map(&:device).select do |device|
        device.controller_key && device.unit_number.nil?
      end

      unnumbered_devices.group_by(&:controller_key).each do |key, devices|
        devices.each_with_index { |d,i| d.unit_number = next_unit_numbers[key] + i }
      end
    end

    def wait_until_off(vm, timeout)
        started = Time.now
        loop do
          power_state = client.get_property(vm, Vim::VirtualMachine, "runtime.powerState")
          break if power_state == Vim::VirtualMachine::PowerState::POWERED_OFF
          raise TimeoutException if Time.now - started > timeout
          sleep(1.0)
        end
    end

    def snapshot_disk(_)
      raise Bosh::Clouds::NotImplemented
    end

    private

    # Despite the naming, this has nothing to do with the Cloud notion of a disk snapshot
    # (which comes from AWS). This is a vm snapshot.
    def take_snapshot(vm, name)
      vm.create_snapshot(name, nil, false, false)
    end

    def folder_url(host, folder_path, datacenter_name, datastore_name)
      query_string = "dcPath=#{URI.escape(datacenter_name)}&dsName=#{URI.escape(datastore_name)}"

      "https://#{host}/folder/#{folder_path}?#{query_string}"
    end

    def fetch_file(datacenter_name, datastore_name, path)
      url = folder_url(Config.vcenter.host, path, datacenter_name, datastore_name)

      retry_block do
        response = @rest_client.get(url)

        return response.body if response.code < 400
        return nil if response.code == 404
        raise "Could not fetch file: #{url}, status code: #{response.code}"
      end
    end


    def upload_file(datacenter_name, datastore_name, path, contents)
      url = folder_url(Config.vcenter.host, path, datacenter_name, datastore_name)

      retry_block do
        response = @rest_client.put(url, contents, {"Content-Type" => "application/octet-stream",
                                                    "Content-Length" => contents.length})

        raise "Could not upload file: #{url}, status code: #{response.code}" if response.code >= 400
      end
    end

    def find_stemcell_vm!(name)
      dc = @resources.datacenters.values.first
      client.find_by_inventory_path([dc.name, "vm", dc.template_folder.name, name]).tap do |stemcell_vm|
        raise "Could not find stemcell: #{name}" unless stemcell_vm
      end
    end

    def place_vm(stemcell_vm, memory, disk_space, disk_locality)
      stemcell_size = client.get_property(
        stemcell_vm,
        Vim::VirtualMachine,
        "summary.storage.committed",
        ensure_all: true
      ) / 1024 * 1024

      disk_spec = disk_locality.map do |disk_cid|
        disk = Models::Disk.first(uuid: disk_cid)
        { size: disk.size, dc_name: disk.datacenter, ds_name: disk.datastore }
      end 

      @resources.place(
        memory,
        disk_space + memory + stemcell_size, #to account for swap and linked clone log
        disk_spec
      )
    end

    def nic_configs(devices, cluster, dvs_index)
      pci_controller_key = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualPCIController) }.key
      networks.map do |_, network|
        v_network_name = network["cloud_properties"]["name"]
        network_mob = client.find_by_inventory_path([cluster.datacenter.name, "network", v_network_name])
        create_nic_config_spec(v_network_name, network_mob, pci_controller_key, dvs_index)
      end
    end

    def nic_deletion_configs(devices)
      devices.
        select { |device| device.kind_of?(Vim::Vm::Device::VirtualEthernetCard) }.
        map { |nic| create_delete_device_spec(nic) }
    end

    def prepare_vm_for_env_data(vm, datacenter_name, datastore, name, devices)
      upload_file(datacenter_name, datastore.name, "#{name}/env.iso", "")
      config = Vim::Vm::ConfigSpec.new
      config.device_change = [configure_env_cdrom(datastore.mob, devices, "[#{datastore.name}] #{name}/env.iso")]
      client.reconfig_vm(vm, config)
    end
  end
end
