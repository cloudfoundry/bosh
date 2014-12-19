require 'json'
require 'membrane'
require 'ruby_vim_sdk'
require 'cloud'
require 'cloud/vsphere/retry_block'
require 'cloud/vsphere/client'
require 'cloud/vsphere/config'
require 'cloud/vsphere/file_provider'
require 'cloud/vsphere/agent_env'
require 'cloud/vsphere/lease_obtainer'
require 'cloud/vsphere/lease_updater'
require 'cloud/vsphere/resources'
require 'cloud/vsphere/resources/cluster'
require 'cloud/vsphere/resources/datacenter'
require 'cloud/vsphere/resources/datastore'
require 'cloud/vsphere/resources/folder'
require 'cloud/vsphere/resources/resource_pool'
require 'cloud/vsphere/resources/scorer'
require 'cloud/vsphere/resources/util'
require 'cloud/vsphere/models/disk'
require 'cloud/vsphere/path_finder'
require 'cloud/vsphere/vm_creator_builder'
require 'cloud/vsphere/fixed_cluster_placer'

module VSphereCloud

  class Cloud < Bosh::Cloud
    include VimSdk
    include RetryBlock

    class TimeoutException < StandardError;
    end

    attr_accessor :client

    def initialize(options)
      @config = Config.build(options)

      @logger = config.logger
      @client = config.client
      @cloud_searcher = CloudSearcher.new(@client.service_content, @logger)

      @resources = Resources.new(config)
      @file_provider = FileProvider.new(config.rest_client, config.vcenter_host)
      @agent_env = AgentEnv.new(client, @file_provider, @cloud_searcher)

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

    def has_disk?(disk_id)
      disk = VSphereCloud::Models::Disk.find(uuid: disk_id)

      return false unless disk
      # Disk path is only being set when disk is created in vSphere.
      # If the path is not set it means that disk was only created in
      # CPI database and attach disk was not called or failed.
      # We consider that disk is missing only if CPI desired state
      # is to be present but it actually missing in infrastructure.
      return true unless disk.path
      return false unless disk.datacenter

      @client.has_disk?(disk.path, disk.datacenter)
    end

    def create_stemcell(image, _)
      with_thread_name("create_stemcell(#{image}, _)") do
        result = nil
        Dir.mktmpdir do |temp_dir|
          @logger.info("Extracting stemcell to: #{temp_dir}")
          output = `tar -C #{temp_dir} -xzf #{image} 2>&1`
          raise "Corrupt image, tar exit status: #{$?.exitstatus} output: #{output}" if $?.exitstatus != 0

          ovf_file = Dir.entries(temp_dir).find { |entry| File.extname(entry) == '.ovf' }
          raise 'Missing OVF' if ovf_file.nil?
          ovf_file = File.join(temp_dir, ovf_file)

          name = "sc-#{generate_unique_name}"
          @logger.info("Generated name: #{name}")

          stemcell_size = File.size(image) / (1024 * 1024)
          cluster, datastore = @resources.place(0, stemcell_size, [])
          @logger.info("Deploying to: #{cluster.mob} / #{datastore.mob}")

          import_spec_result = import_ovf(name, ovf_file, cluster.resource_pool.mob, datastore.mob)

          lease_obtainer = LeaseObtainer.new(@cloud_searcher, @logger)
          nfc_lease = lease_obtainer.obtain(
            cluster.resource_pool,
            import_spec_result.import_spec,
            cluster.datacenter.template_folder,
          )

          @logger.info('Uploading')
          vm = upload_ovf(ovf_file, nfc_lease, import_spec_result.file_item)
          result = name

          @logger.info('Removing NICs')
          devices = @cloud_searcher.get_property(vm, Vim::VirtualMachine, 'config.hardware.device', ensure_all: true)
          config = Vim::Vm::ConfigSpec.new
          config.device_change = []

          nics = devices.select { |device| device.kind_of?(Vim::Vm::Device::VirtualEthernetCard) }
          nics.each do |nic|
            nic_config = create_delete_device_spec(nic)
            config.device_change << nic_config
          end
          client.reconfig_vm(vm, config)

          @logger.info('Taking initial snapshot')

          # Despite the naming, this has nothing to do with the Cloud notion of a disk snapshot
          # (which comes from AWS). This is a vm snapshot.
          task = vm.create_snapshot('initial', nil, false, false)
          client.wait_for_task(task)
        end
        result
      end
    end

    def delete_stemcell(stemcell)
      with_thread_name("delete_stemcell(#{stemcell})") do
        Bosh::ThreadPool.new(max_threads: 32, logger: @logger).wrap do |pool|
          @resources.datacenters.each_value do |datacenter|
            @logger.info("Looking for stemcell replicas in: #{datacenter.name}")
            templates = @cloud_searcher.get_property(datacenter.template_folder.mob, Vim::Folder, 'childEntity', ensure_all: true)
            template_properties = @cloud_searcher.get_properties(templates, Vim::VirtualMachine, ['name'])
            template_properties.each_value do |properties|
              template_name = properties['name'].gsub('%2f', '/')
              if template_name.split('/').first.strip == stemcell
                @logger.info("Found: #{template_name}")
                pool.process do
                  @logger.info("Deleting: #{template_name}")
                  client.delete_vm(properties[:obj])
                  @logger.info("Deleted: #{template_name}")
                end
              end
            end
          end
        end
      end
    end

    def disk_spec(persistent_disks)
      disks = []
      if persistent_disks
        persistent_disks.each do |disk_cid|
          disk = Models::Disk.first(uuid: disk_cid)
          disks << {
            size: disk.size,
            dc_name: disk.datacenter,
            ds_name: disk.datastore
          }
        end
      end
      disks
    end

    def stemcell_vm(name)
      dc = @resources.datacenters.values.first
      client.find_by_inventory_path([dc.name, 'vm', dc.template_folder.path, name])
    end

    def create_vm(agent_id, stemcell, cloud_properties, networks, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        VmCreatorBuilder.new.build(
          choose_placer(cloud_properties),
          cloud_properties,
          @client,
          @cloud_searcher,
          @logger,
          self,
          @agent_env,
          @file_provider
        ).create(agent_id, stemcell, networks, disk_locality, environment)
      end
    end

    def delete_vm(vm_cid)
      with_thread_name("delete_vm(#{vm_cid})") do
        @logger.info("Deleting vm: #{vm_cid}")

        vm = get_vm_by_cid(vm_cid)
        datacenter = client.find_parent(vm, Vim::Datacenter)
        properties =
          @cloud_searcher.get_properties(
            vm,
            Vim::VirtualMachine,
            ['runtime.powerState', 'runtime.question', 'config.hardware.device', 'name'],
            ensure: ['config.hardware.device']
          )

        retry_block do
          question = properties['runtime.question']
          if question
            choices = question.choice
            @logger.info("VM is blocked on a question: #{question.text}, " +
                           "providing default answer: #{choices.choice_info[choices.default_index].label}")
            client.answer_vm(vm, question.id, choices.choice_info[choices.default_index].key)
            power_state = @cloud_searcher.get_property(vm, Vim::VirtualMachine, 'runtime.powerState')
          else
            power_state = properties['runtime.powerState']
          end

          if power_state != Vim::VirtualMachine::PowerState::POWERED_OFF
            @logger.info("Powering off vm: #{vm_cid}")
            client.power_off_vm(vm)
          end
        end

        # Detach any persistent disks in case they were not detached from the instance
        devices = properties['config.hardware.device']
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

        # Delete env.iso and VM specific files managed by the director
        retry_block do
          cdrom = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualCdrom) }
          @agent_env.clean_env(vm) if cdrom
        end

        retry_block { client.delete_vm(vm) }
        @logger.info("Deleted vm: #{vm_cid}")
      end
    end

    def reboot_vm(vm_cid)
      with_thread_name("reboot_vm(#{vm_cid})") do
        vm = get_vm_by_cid(vm_cid)
        datacenter = client.find_parent(vm, Vim::Datacenter)
        power_state = @cloud_searcher.get_property(vm, Vim::VirtualMachine, 'runtime.powerState')

        @logger.info("Reboot vm = #{vm_cid}")
        if power_state != Vim::VirtualMachine::PowerState::POWERED_ON
          @logger.info("VM not in POWERED_ON state. Current state : #{power_state}")
        end
        begin
          vm.reboot_guest
        rescue => e
          @logger.error("Soft reboot failed #{e} -#{e.backtrace.join("\n")}")
          @logger.info('Try hard reboot')
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
              field = fields_manager.add_field_definition(name.to_s, Vim::VirtualMachine, nil, nil)
            end
            name_to_key_id[name] = field.key
          end

          vm = get_vm_by_cid(vm_cid)

          metadata.each do |name, value|
            value = '' if value.nil? # value is required
            fields_manager.set_field(vm, name_to_key_id[name], value)
          end
        rescue SoapError => e
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

        @logger.debug('Waiting for the VM to shutdown')
        begin
          begin
            vm.shutdown_guest
          rescue => e
            @logger.debug("Ignoring possible race condition when a VM has powered off by the time we ask it to shutdown: #{e.inspect}")
          end

          wait_until_off(vm, 60)
        rescue TimeoutException
          @logger.debug('The guest did not shutdown in time, requesting it to power off')
          client.power_off_vm(vm)
        end

        @logger.info("Configuring: #{vm_cid} to use the following network settings: #{networks.pretty_inspect}")
        vm = get_vm_by_cid(vm_cid)
        devices = @cloud_searcher.get_property(vm, Vim::VirtualMachine, 'config.hardware.device', ensure_all: true)
        datacenter = client.find_parent(vm, Vim::Datacenter)
        datacenter_name = config.datacenter_name
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
          v_network_name = network['cloud_properties']['name']
          network_mob = client.find_by_inventory_path([datacenter_name, 'network', v_network_name])
          nic_config = create_nic_config_spec(v_network_name, network_mob, pci_controller.key, dvs_index)
          config.device_change << nic_config
        end

        fix_device_unit_numbers(devices, config.device_change)
        @logger.debug('Reconfiguring the networks')
        @client.reconfig_vm(vm, config)

        env = @agent_env.get_current_env(vm, datacenter_name)
        @logger.debug("Reading current agent env: #{env.pretty_inspect}")

        devices = @cloud_searcher.get_property(vm, Vim::VirtualMachine, 'config.hardware.device', ensure_all: true)
        env['networks'] = generate_network_env(devices, networks, dvs_index)

        @logger.debug("Updating agent env to: #{env.pretty_inspect}")
        location = get_vm_location(vm, datacenter: datacenter_name)
        @agent_env.set_env(vm, location, env)

        @logger.debug('Powering the VM back on')
        client.power_on_vm(datacenter, vm)
      end
    end

    def get_vm_host_info(vm_ref)
      vm = @cloud_searcher.get_properties(vm_ref, Vim::VirtualMachine, 'runtime')
      vm_runtime = vm['runtime']

      properties = @cloud_searcher.get_properties(vm_runtime.host, Vim::HostSystem, ['datastore', 'parent'], ensure_all: true)

      # Get the cluster that the vm's host belongs to.
      cluster = @cloud_searcher.get_properties(properties['parent'], Vim::ClusterComputeResource, 'name')

      # Get the datastores that are accessible to the vm's host.
      datastores_accessible = []
      properties['datastore'].each do |store|
        ds = @cloud_searcher.get_properties(store, Vim::Datastore, 'info', ensure_all: true)
        datastores_accessible << ds['info'].name
      end

      { 'cluster' => cluster['name'], 'datastores' => datastores_accessible }
    end

    def find_persistent_datastore(datacenter_name, host_info, disk_size)
      # Find datastore
      datastore = @resources.place_persistent_datastore(datacenter_name, host_info['cluster'], disk_size)

      if datastore.nil?
        raise Bosh::Clouds::NoDiskSpace.new(true), "Not enough persistent space on cluster #{host_info['cluster']}, #{disk_size}"
      end

      # Sanity check, verify that the vm's host can access this datastore
      unless host_info['datastores'].include?(datastore.name)
        raise "Datastore not accessible to host, #{datastore.name}, #{host_info['datastores']}"
      end
      datastore
    end

    def attach_disk(vm_cid, disk_cid)
      with_thread_name("attach_disk(#{vm_cid}, #{disk_cid})") do
        @logger.info("Attaching disk: #{disk_cid} on vm: #{vm_cid}")
        disk = Models::Disk.first(uuid: disk_cid)
        raise "Disk not found: #{disk_cid}" if disk.nil?

        vm = get_vm_by_cid(vm_cid)

        datacenter = client.find_parent(vm, Vim::Datacenter)
        datacenter_name = config.datacenter_name

        vm_properties = @cloud_searcher.get_properties(vm, Vim::VirtualMachine, 'config.hardware.device', ensure_all: true)
        host_info = get_vm_host_info(vm)

        create_disk = false
        if disk.path

          disk_in_correct_datacenter =
            (disk.datacenter == datacenter_name &&
              @resources.validate_persistent_datastore(datacenter_name, disk.datastore) &&
              host_info['datastores'].include?(disk.datastore))

          if disk_in_correct_datacenter
            @logger.info("Disk already in the right datastore #{datacenter_name} #{disk.datastore}")
            persistent_datastore =
              @resources.persistent_datastore(datacenter_name, host_info['cluster'], disk.datastore)
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

            if config.copy_disks
              client.copy_disk(source_datacenter, source_path, datacenter, destination_path)
              @logger.info('Copied disk successfully')
            else
              client.move_disk(source_datacenter, source_path, datacenter, destination_path)
              @logger.info('Moved disk successfully')
            end

            disk.datacenter = datacenter_name
            disk.datastore = persistent_datastore.name
            disk.path = destination_path
            disk.save
          end
        else
          @logger.info('Need to create disk')

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

        devices = vm_properties['config.hardware.device']
        system_disk = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualDisk) }

        vmdk_path = "#{disk.path}.vmdk"
        attached_disk_config = create_disk_config_spec(persistent_datastore.mob,
                                                       vmdk_path,
                                                       system_disk.controller_key,
                                                       disk.size.to_i,
                                                       create: create_disk, independent: true)
        config = Vim::Vm::ConfigSpec.new
        config.device_change = []
        config.device_change << attached_disk_config
        fix_device_unit_numbers(devices, config.device_change)

        env = @agent_env.get_current_env(vm, datacenter_name)
        @logger.info("Reading current agent env: #{env.pretty_inspect}")
        env['disks']['persistent'][disk.uuid] = attached_disk_config.device.unit_number.to_s
        @logger.info("Updating agent env to: #{env.pretty_inspect}")

        location = get_vm_location(vm, datacenter: datacenter_name)
        @agent_env.set_env(vm, location, env)
        @logger.info('Attaching disk')
        client.reconfig_vm(vm, config)
        @logger.info('Finished attaching disk')
      end
    end

    def detach_disk(vm_cid, disk_cid)
      with_thread_name("detach_disk(#{vm_cid}, #{disk_cid})") do
        @logger.info("Detaching disk: #{disk_cid} from vm: #{vm_cid}")
        disk = Models::Disk.first(uuid: disk_cid)
        raise "Disk not found: #{disk_cid}" if disk.nil?

        vm = get_vm_by_cid(vm_cid)

        location = get_vm_location(vm)
        env = @agent_env.get_current_env(vm, location[:datacenter])
        @logger.info("Reading current agent env: #{env.pretty_inspect}")
        if env['disks']['persistent'][disk.uuid]
          env['disks']['persistent'].delete(disk.uuid)
          @logger.info("Updating agent env to: #{env.pretty_inspect}")

          @agent_env.set_env(vm, location, env)
        end

        devices = @cloud_searcher.get_property(vm, Vim::VirtualMachine, 'config.hardware.device', ensure_all: true)
        virtual_disk =
          devices.find do |device|
            device.kind_of?(Vim::Vm::Device::VirtualDisk) && device.backing.file_name.end_with?("/#{disk_cid}.vmdk")
          end
        raise Bosh::Clouds::DiskNotAttached.new(true), "Disk (#{disk_cid}) is not attached to VM (#{vm_cid})" if virtual_disk.nil?

        config = Vim::Vm::ConfigSpec.new
        config.device_change = []
        config.device_change << create_delete_device_spec(virtual_disk)

        @logger.info('Detaching disk')
        client.reconfig_vm(vm, config)

        # detach-disk is async and task completion does not necessarily mean
        # that changes have been applied to VC side. Query VC until we confirm
        # that the change has been applied. This is a known issue for vsphere 4.
        # Fixed in vsphere 5.
        5.times do
          devices = @cloud_searcher.get_property(vm, Vim::VirtualMachine, 'config.hardware.device', ensure_all: true)
          virtual_disk =
            devices.find do |device|
              device.kind_of?(Vim::Vm::Device::VirtualDisk) &&
                device.backing.file_name.end_with?("/#{disk_cid}.vmdk")
            end
          break if virtual_disk.nil?
          sleep(1.0)
        end
        raise "Failed to detach disk: #{disk_cid} from vm: #{vm_cid}" unless virtual_disk.nil?

        @logger.info('Finished detaching disk')
      end
    end

    def create_disk(size, cloud_properties, _ = nil)
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
          unless has_disk?(disk_cid)
            raise Bosh::Clouds::DiskNotFound.new(true), "disk #{disk_cid} not found"
          end

          datacenter = client.find_by_inventory_path(disk.datacenter)
          if datacenter.nil?
            raise Bosh::Clouds::DiskNotFound.new(true), "datacenter for disk #{disk_cid} not found"
          end

          client.delete_disk(datacenter, disk.path) if disk.path

          disk.destroy
          @logger.info('Finished deleting disk')
        else
          raise "Could not find disk: #{disk_cid}"
        end
      end
    end

    def get_vm_by_cid(vm_cid)
      @resources.datacenters.each_value do |datacenter|
        vm = client.find_by_inventory_path([datacenter.name, 'vm', datacenter.vm_folder.path, vm_cid])
        return vm unless vm.nil?
      end
      raise Bosh::Clouds::VMNotFound, "VM `#{vm_cid}' not found"
    end

    def replicate_stemcell(cluster, datastore, stemcell)
      stemcell_vm = client.find_by_inventory_path([cluster.datacenter.name, 'vm',
                                                   cluster.datacenter.template_folder.path, stemcell])
      raise "Could not find stemcell: #{stemcell}" if stemcell_vm.nil?
      stemcell_datastore = @cloud_searcher.get_property(stemcell_vm, Vim::VirtualMachine, 'datastore', ensure_all: true)

      if stemcell_datastore != datastore.mob
        @logger.info("Stemcell lives on a different datastore, looking for a local copy of: #{stemcell}.")
        local_stemcell_name = "#{stemcell} %2f #{datastore.mob.__mo_id__}"
        local_stemcell_path =
          [cluster.datacenter.name, 'vm', cluster.datacenter.template_folder.path, local_stemcell_name]
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
              task = clone_vm(stemcell_vm,
                              local_stemcell_name,
                              cluster.datacenter.template_folder.mob,
                              cluster.resource_pool.mob,
                              datastore: datastore.mob)
              replicated_stemcell_vm = client.wait_for_task(task)
              @logger.info("Replicated #{stemcell} (#{stemcell_vm}) to #{local_stemcell_name} (#{replicated_stemcell_vm})")
              @logger.info("Creating initial snapshot for linked clones on #{replicated_stemcell_vm}")
              # Despite the naming, this has nothing to do with the Cloud notion of a disk snapshot
              # (which comes from AWS). This is a vm snapshot.
              task = replicated_stemcell_vm.create_snapshot('initial', nil, false, false)
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
            v_network_name = dvs_index[backing.port.portgroup_key]
          else
            v_network_name = PathFinder.new.path(backing.network)
          end
          allocated_networks = nics[v_network_name] || []
          allocated_networks << device
          nics[v_network_name] = allocated_networks
        end
      end

      network_env = {}
      networks.each do |network_name, network|
        network_entry = network.dup
        v_network_name = network['cloud_properties']['name']
        nic = nics[v_network_name].pop
        network_entry['mac'] = nic.mac_address
        network_env[network_name] = network_entry
      end
      network_env
    end

    def generate_disk_env(system_disk, ephemeral_disk)
      {
        'system' => system_disk.unit_number.to_s,
        'ephemeral' => ephemeral_disk.unit_number.to_s,
        'persistent' => {}
      }
    end

    def generate_agent_env(name, vm, agent_id, networking_env, disk_env)
      vm_env = {
        'name' => name,
        'id' => vm.__mo_id__
      }

      env = {}
      env['vm'] = vm_env
      env['agent_id'] = agent_id
      env['networks'] = networking_env
      env['disks'] = disk_env
      env.merge!(config.agent)
      env
    end

    def get_vm_location(vm, options = {})
      datacenter_name = options[:datacenter]
      datastore_name = options[:datastore]
      vm_name = options[:vm]

      unless datacenter_name
        datacenter_name = config.datacenter_name
      end

      if vm_name.nil? || datastore_name.nil?
        vm_properties =
          @cloud_searcher.get_properties(vm, Vim::VirtualMachine, ['config.hardware.device', 'name'], ensure_all: true)
        vm_name = vm_properties['name']

        unless datastore_name
          devices = vm_properties['config.hardware.device']
          datastore = get_primary_datastore(devices)
          datastore_name = @cloud_searcher.get_property(datastore, Vim::Datastore, 'name')
        end
      end

      { datacenter: datacenter_name, datastore: datastore_name, vm: vm_name }
    end

    def get_primary_datastore(devices)
      ephemeral_disks = devices.select { |device| device.kind_of?(Vim::Vm::Device::VirtualDisk) &&
        device.backing.disk_mode != Vim::Vm::Device::VirtualDiskOption::DiskMode::INDEPENDENT_PERSISTENT }

      datastore = nil
      ephemeral_disks.each do |disk|
        if datastore
          raise 'Ephemeral disks should all be on the same datastore.' unless datastore.eql?(disk.backing.datastore)
        else
          datastore = disk.backing.datastore
        end
      end

      datastore
    end

    def clone_vm(vm, name, folder, resource_pool, options={})
      relocation_spec = Vim::Vm::RelocateSpec.new
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

    def create_disk_config_spec(datastore, file_name, controller_key, space, options = {})
      backing_info = Vim::Vm::Device::VirtualDisk::FlatVer2BackingInfo.new
      backing_info.datastore = datastore
      if options[:independent]
        backing_info.disk_mode = Vim::Vm::Device::VirtualDiskOption::DiskMode::INDEPENDENT_PERSISTENT
      else
        backing_info.disk_mode = Vim::Vm::Device::VirtualDiskOption::DiskMode::PERSISTENT
      end
      backing_info.file_name = file_name

      virtual_disk = Vim::Vm::Device::VirtualDisk.new
      virtual_disk.key = -1
      virtual_disk.controller_key = controller_key
      virtual_disk.backing = backing_info
      virtual_disk.capacity_in_kb = space * 1024

      device_config_spec = Vim::Vm::Device::VirtualDeviceSpec.new
      device_config_spec.device = virtual_disk
      device_config_spec.operation = Vim::Vm::Device::VirtualDeviceSpec::Operation::ADD
      if options[:create]
        device_config_spec.file_operation = Vim::Vm::Device::VirtualDeviceSpec::FileOperation::CREATE
      end
      device_config_spec
    end

    def create_nic_config_spec(v_network_name, network, controller_key, dvs_index)
      raise "Can't find network: #{v_network_name}" if network.nil?
      if network.class == Vim::Dvs::DistributedVirtualPortgroup
        portgroup_properties = @cloud_searcher.get_properties(network,
                                                     Vim::Dvs::DistributedVirtualPortgroup,
                                                     ['config.key', 'config.distributedVirtualSwitch'],
                                                     ensure_all: true)

        switch = portgroup_properties['config.distributedVirtualSwitch']
        switch_uuid = @cloud_searcher.get_property(switch, Vim::DistributedVirtualSwitch, 'uuid', ensure_all: true)

        port = Vim::Dvs::PortConnection.new
        port.switch_uuid = switch_uuid
        port.portgroup_key = portgroup_properties['config.key']

        backing_info = Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo.new
        backing_info.port = port

        dvs_index[port.portgroup_key] = v_network_name
      else
        backing_info = Vim::Vm::Device::VirtualEthernetCard::NetworkBackingInfo.new
        backing_info.device_name = network.name
        backing_info.network = network
      end

      nic = Vim::Vm::Device::VirtualVmxnet3.new
      nic.key = -1
      nic.controller_key = controller_key
      nic.backing = backing_info

      device_config_spec = Vim::Vm::Device::VirtualDeviceSpec.new
      device_config_spec.device = nic
      device_config_spec.operation = Vim::Vm::Device::VirtualDeviceSpec::Operation::ADD
      device_config_spec
    end

    def create_delete_device_spec(device, options = {})
      device_config_spec = Vim::Vm::Device::VirtualDeviceSpec.new
      device_config_spec.device = device
      device_config_spec.operation = Vim::Vm::Device::VirtualDeviceSpec::Operation::REMOVE
      if options[:destroy]
        device_config_spec.file_operation = Vim::Vm::Device::VirtualDeviceSpec::FileOperation::DESTROY
      end
      device_config_spec
    end

    def fix_device_unit_numbers(devices, device_changes)
      controllers_available_unit_numbers = Hash.new { |h,k| h[k] = (0..15).to_a }
      devices.each do |device|
        if device.controller_key
          available_unit_numbers = controllers_available_unit_numbers[device.controller_key]
          available_unit_numbers.delete(device.unit_number)
        end
      end

      device_changes.each do |device_change|
        device = device_change.device
        if device.controller_key && device.unit_number.nil?
          available_unit_numbers = controllers_available_unit_numbers[device.controller_key]
          raise "No available unit numbers for device: #{device.inspect}" if available_unit_numbers.empty?
          device.unit_number = available_unit_numbers.shift
        end
      end
    end

    def import_ovf(name, ovf, resource_pool, datastore)
      import_spec_params = Vim::OvfManager::CreateImportSpecParams.new
      import_spec_params.entity_name = name
      import_spec_params.locale = 'US'
      import_spec_params.deployment_option = ''

      ovf_file = File.open(ovf)
      ovf_descriptor = ovf_file.read
      ovf_file.close

      @client.service_content.ovf_manager.create_import_spec(ovf_descriptor,
                                                             resource_pool,
                                                             datastore,
                                                             import_spec_params)
    end

    def obtain_nfc_lease(resource_pool, import_spec, folder)
      resource_pool.import_vapp(import_spec, folder, nil)
    end

    def wait_for_nfc_lease(lease)
      loop do
        state = @cloud_searcher.get_property(lease, Vim::HttpNfcLease, 'state')
        return state unless state == Vim::HttpNfcLease::State::INITIALIZING
        sleep(1.0)
      end
    end

    def upload_ovf(ovf, lease, file_items)
      info = @cloud_searcher.get_property(lease, Vim::HttpNfcLease, 'info', ensure_all: true)
      lease_updater = LeaseUpdater.new(client, lease)

      info.device_url.each do |device_url|
        device_key = device_url.import_key
        file_items.each do |file_item|
          if device_key == file_item.device_id
            http_client = HTTPClient.new
            http_client.send_timeout = 14400 # 4 hours
            http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

            disk_file_path = File.join(File.dirname(ovf), file_item.path)
            disk_file = File.open(disk_file_path)
            disk_file_size = File.size(disk_file_path)

            progress_thread = Thread.new do
              loop do
                lease_updater.progress = disk_file.pos * 100 / disk_file_size
                sleep(2)
              end
            end

            @logger.info("Uploading disk to: #{device_url.url}")

            http_client.post(device_url.url,
                             disk_file,
                             { 'Content-Type' => 'application/x-vnd.vmware-streamVmdk', 'Content-Length' => disk_file_size })

            progress_thread.kill
            disk_file.close
          end
        end
      end
      lease_updater.finish
      info.entity
    end

    def wait_until_off(vm, timeout)
      started = Time.now
      loop do
        power_state = @cloud_searcher.get_property(vm, Vim::VirtualMachine, 'runtime.powerState')
        break if power_state == Vim::VirtualMachine::PowerState::POWERED_OFF
        raise TimeoutException if Time.now - started > timeout
        sleep(1.0)
      end
    end

    def get_vms
      subfolders = []
      with_thread_name("get_vms") do
        @resources.datacenters.each_value do |datacenter|
          @logger.info("Looking for VMs in: #{datacenter.name} - #{datacenter.master_vm_folder.name}")
          subfolders += datacenter.master_vm_folder.mob.child_entity
          @logger.info("Looking for Stemcells in: #{datacenter.name} - #{datacenter.master_template_folder.name}")
          subfolders += datacenter.master_template_folder.mob.child_entity
        end
      end

      subfolders.map { |folder| folder.child_entity }.flatten
    end

    def ping
      "pong"
    end

    private

    def choose_placer(cloud_properties)
      datacenter_spec = cloud_properties.fetch('datacenters', []).first
      cluster_spec = datacenter_spec.fetch('clusters', []).first if datacenter_spec

      unless cluster_spec.nil?
        cluster_name = cluster_spec.keys.first
        cluster = find_cluster(cluster_name)
        cluster_config = cluster_spec.values.first
        drs_rules = cluster_config.fetch('drs_rules', [])
        placer = FixedClusterPlacer.new(cluster, drs_rules)
      end

      placer.nil? ? @resources : placer
    end

    def find_cluster(cluster_name)
      datacenter = Resources::Datacenter.new(config)
      datacenter.clusters[cluster_name]
    end

    attr_reader :config
  end
end
