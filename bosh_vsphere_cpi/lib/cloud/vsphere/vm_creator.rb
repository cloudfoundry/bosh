module VSphereCloud
  class VmCreator
    def initialize(resources, client, logger, cpi)
      @resources = resources
      @client = client
      @logger = logger
      @cpi = cpi
    end

    def create(agent_id, stemcell, cloud_properties, networks, disk_locality, environment)
      memory = cloud_properties['ram']
      disk = cloud_properties['disk']
      cpu = cloud_properties['cpu']

      # Make sure number of cores is a power of 2. kb.vmware.com/kb/2003484
      if cpu & cpu - 1 != 0
        raise "Number of vCPUs: #{cpu} is not a power of 2."
      end

      stemcell_vm = @cpi.stemcell_vm(stemcell)
      raise "Could not find stemcell: #{stemcell}" if stemcell_vm.nil?

      stemcell_size =
        @client.get_property(stemcell_vm, VimSdk::Vim::VirtualMachine, 'summary.storage.committed', ensure_all: true)
      stemcell_size /= 1024 * 1024

      disks = @cpi.disk_spec(disk_locality)
      # need to include swap and linked clone log
      ephemeral = disk + memory + stemcell_size
      cluster, datastore = @resources.place(memory, ephemeral, disks)

      name = "vm-#{@cpi.generate_unique_name}"
      @logger.info("Creating vm: #{name} on #{cluster.mob} stored in #{datastore.mob}")

      replicated_stemcell_vm = @cpi.replicate_stemcell(cluster, datastore, stemcell)
      replicated_stemcell_properties = @client.get_properties(replicated_stemcell_vm, VimSdk::Vim::VirtualMachine,
                                                             ['config.hardware.device', 'snapshot'],
                                                             ensure_all: true)

      devices = replicated_stemcell_properties['config.hardware.device']
      snapshot = replicated_stemcell_properties['snapshot']

      config = VimSdk::Vim::Vm::ConfigSpec.new(memory_mb: memory, num_cpus: cpu)
      config.device_change = []

      system_disk = devices.find { |device| device.kind_of?(VimSdk::Vim::Vm::Device::VirtualDisk) }
      pci_controller = devices.find { |device| device.kind_of?(VimSdk::Vim::Vm::Device::VirtualPCIController) }

      file_name = "[#{datastore.name}] #{name}/ephemeral_disk.vmdk"
      ephemeral_disk_config =
        @cpi.create_disk_config_spec(datastore.mob, file_name, system_disk.controller_key, disk, create: true)
      config.device_change << ephemeral_disk_config

      dvs_index = {}
      networks.each_value do |network|
        v_network_name = network['cloud_properties']['name']
        network_mob = @client.find_by_inventory_path([cluster.datacenter.name, 'network', v_network_name])
        nic_config = @cpi.create_nic_config_spec(v_network_name, network_mob, pci_controller.key, dvs_index)
        config.device_change << nic_config
      end

      nics = devices.select { |device| device.kind_of?(VimSdk::Vim::Vm::Device::VirtualEthernetCard) }
      nics.each do |nic|
        nic_config = @cpi.create_delete_device_spec(nic)
        config.device_change << nic_config
      end

      @cpi.fix_device_unit_numbers(devices, config.device_change)

      @logger.info("Cloning vm: #{replicated_stemcell_vm} to #{name}")

      task = @cpi.clone_vm(replicated_stemcell_vm,
                      name,
                      cluster.datacenter.vm_folder.mob,
                      cluster.resource_pool.mob,
                      datastore: datastore.mob, linked: true, snapshot: snapshot.current_snapshot, config: config)
      vm = @client.wait_for_task(task)

      begin
        @cpi.upload_file(cluster.datacenter.name, datastore.name, "#{name}/env.iso", '')

        vm_properties = @client.get_properties(vm, VimSdk::Vim::VirtualMachine, ['config.hardware.device'], ensure_all: true)
        devices = vm_properties['config.hardware.device']

        # Configure the ENV CDROM
        config = VimSdk::Vim::Vm::ConfigSpec.new
        config.device_change = []
        file_name = "[#{datastore.name}] #{name}/env.iso"
        cdrom_change = @cpi.configure_env_cdrom(datastore.mob, devices, file_name)
        config.device_change << cdrom_change
        @client.reconfig_vm(vm, config)

        network_env = @cpi.generate_network_env(devices, networks, dvs_index)
        disk_env = @cpi.generate_disk_env(system_disk, ephemeral_disk_config.device)
        env = @cpi.generate_agent_env(name, vm, agent_id, network_env, disk_env)
        env['env'] = environment
        @logger.info("Setting VM env: #{env.pretty_inspect}")

        location =
          @cpi.get_vm_location(vm, datacenter: cluster.datacenter.name, datastore: datastore.name, vm: name)
        @cpi.set_agent_env(vm, location, env)

        @logger.info("Powering on VM: #{vm} (#{name})")
        @client.power_on_vm(cluster.datacenter.mob, vm)
      rescue => e
        @logger.info("#{e} - #{e.backtrace.join("\n")}")
        @cpi.delete_vm(name)
        raise e
      end
      name
    end
  end
end
