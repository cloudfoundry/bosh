module VSphereCloud
  class VmCreator
    def initialize(memory, disk_size_in_mb, cpu, nested_hardware_virtualization, placer, client, cloud_searcher, logger, cpi, agent_env, file_provider, disk_provider)
      @placer = placer
      @client = client
      @cloud_searcher = cloud_searcher
      @logger = logger
      @cpi = cpi
      @memory = memory
      @disk_size_in_mb = disk_size_in_mb
      @cpu = cpu
      @nested_hardware_virtualization = nested_hardware_virtualization
      @agent_env = agent_env
      @file_provider = file_provider
      @disk_provider = disk_provider

      @logger.debug("VM creator initialized with memory: #{@memory}, disk: #{@disk}, cpu: #{@cpu}, placer: #{@placer}")
    end

    def create(agent_id, stemcell_cid, networks, persistent_disk_cids, environment)
      stemcell_vm = @cpi.stemcell_vm(stemcell_cid)
      raise "Could not find stemcell: #{stemcell_cid}" if stemcell_vm.nil?

      stemcell_size =
        @cloud_searcher.get_property(stemcell_vm, VimSdk::Vim::VirtualMachine, 'summary.storage.committed', ensure_all: true)
      stemcell_size /= 1024 * 1024

      persistent_disk_cids ||= []
      persistent_disks = persistent_disk_cids.map { |cid| @disk_provider.find(cid) }

      # need to include swap and linked clone log
      ephemeral_disk_size_in_mb = @disk_size_in_mb + @memory + stemcell_size
      cluster = @placer.pick_cluster_for_vm(@memory, ephemeral_disk_size_in_mb, persistent_disks)
      datastore = @placer.pick_ephemeral_datastore(cluster, ephemeral_disk_size_in_mb)

      vm_cid = "vm-#{SecureRandom.uuid}"
      @logger.info("Creating vm: #{vm_cid} on #{cluster.mob} stored in #{datastore.mob}")

      replicated_stemcell_vm_mob = @cpi.replicate_stemcell(cluster, datastore, stemcell_cid)
      replicated_stemcell_properties = @cloud_searcher.get_properties(replicated_stemcell_vm_mob, VimSdk::Vim::VirtualMachine,
        ['snapshot'],
        ensure_all: true)
      replicated_stemcell_vm = Resources::VM.new(stemcell_cid, replicated_stemcell_vm_mob, @client, @logger)
      snapshot = replicated_stemcell_properties['snapshot']

      config_hash = {memory_mb: @memory, num_cpus: @cpu}
      config_hash.merge!(nested_hv_enabled: true) if @nested_hardware_virtualization

      config = VimSdk::Vim::Vm::ConfigSpec.new(config_hash)
      config.device_change = []

      ephemeral_disk = VSphereCloud::EphemeralDisk.new(@disk_size_in_mb, vm_cid, datastore)
      ephemeral_disk_config = ephemeral_disk.create_spec(replicated_stemcell_vm.system_disk.controller_key)
      config.device_change << ephemeral_disk_config

      dvs_index = {}
      networks.each_value do |network|
        v_network_name = network['cloud_properties']['name']
        network_mob = @client.find_by_inventory_path([cluster.datacenter.name, 'network', v_network_name])
        nic_config = @cpi.create_nic_config_spec(v_network_name, network_mob, replicated_stemcell_vm.pci_controller.key, dvs_index)
        config.device_change << nic_config
      end

      replicated_stemcell_vm.nics.each do |nic|
        nic_config = @cpi.create_delete_device_spec(nic)
        config.device_change << nic_config
      end

      replicated_stemcell_vm.fix_device_unit_numbers(config.device_change)

      @logger.info("Cloning vm: #{replicated_stemcell_vm} to #{vm_cid}")

      task = @cpi.clone_vm(replicated_stemcell_vm.mob,
        vm_cid,
        cluster.datacenter.vm_folder.mob,
        cluster.resource_pool.mob,
        datastore: datastore.mob, linked: true, snapshot: snapshot.current_snapshot, config: config)
      created_vm_mob = @client.wait_for_task(task)
      created_vm = Resources::VM.new(vm_cid, created_vm_mob, @client, @logger)

      begin
        network_env = @cpi.generate_network_env(created_vm.devices, networks, dvs_index)
        disk_env = @cpi.generate_disk_env(created_vm.system_disk, ephemeral_disk_config.device)
        env = @cpi.generate_agent_env(created_vm.cid, created_vm.mob, agent_id, network_env, disk_env)
        env['env'] = environment
        @logger.info("Setting VM env: #{env.pretty_inspect}")

        location = @cpi.get_vm_location(
          created_vm.mob,
          datacenter: cluster.datacenter.name,
          datastore: datastore.name,
          vm: created_vm.cid
        )

        @agent_env.set_env(created_vm.mob, location, env)

        @logger.info("Powering on VM: #{created_vm} (#{created_vm.cid})")
        created_vm.power_on

        create_drs_rules(created_vm.mob, cluster)
      rescue => e
        @logger.info("#{e} - #{e.backtrace.join("\n")}")
        created_vm.delete if created_vm
        raise e
      end

      vm_cid
    end

    def create_drs_rules(vm, cluster)
      return unless @placer.drs_rules
      return if @placer.drs_rules.size == 0

      if @placer.drs_rules.size > 1
        raise 'vSphere CPI supports only one DRS rule per resource pool'
      end

      rule_config = @placer.drs_rules.first

      if rule_config['type'] != 'separate_vms'
        raise "vSphere CPI only supports DRS rule of 'separate_vms' type"
      end

      drs_rule = VSphereCloud::DrsRule.new(
        rule_config['name'],
        @client,
        @cloud_searcher,
        cluster.mob,
        @logger
      )
      drs_rule.add_vm(vm)
    end
  end
end
