require "ruby_vim_sdk"
require "cloud/vsphere/client"
require "cloud/vsphere/lease_updater"
require "cloud/vsphere/resources"
require "cloud/vsphere/models/disk"

module VSphereCloud

  class Cloud < Bosh::Cloud
    include VimSdk

    class TimeoutException < StandardError; end

    attr_accessor :client

    def initialize(options)
      @vcenters = options["vcenters"]
      raise "Invalid number of VCenters" unless @vcenters.size == 1
      @vcenter = @vcenters[0]

      @logger = Bosh::Clouds::Config.logger

      @agent_properties = options["agent"]

      @client = Client.new("https://#{@vcenter["host"]}/sdk/vimService", options)
      @client.login(@vcenter["user"], @vcenter["password"], "en")

      @rest_client = HTTPClient.new
      @rest_client.send_timeout = 14400 # 4 hours
      @rest_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      # HACK: read the session from the SOAP client so we don't leak sessions when using the REST client
      cookie_str = @client.stub.cookie
      @rest_client.cookie_manager.parse(cookie_str, URI.parse("https://#{@vcenter["host"]}"))

      mem_ratio = 1.0
      if options["mem_overcommit_ratio"]
        mem_ratio = options["mem_overcommit_ratio"].to_f
      end

      @resources = Resources.new(@client, @vcenter, mem_ratio)

      # HACK: provide a way to copy the disks instead of moving them.
      # Used for extra data protection until we have proper backups
      @copy_disks = options["copy_disks"] || false

      @lock = Mutex.new
      @locks = {}
      @locks_mutex = Mutex.new

      # We get disconnected if the connection is inactive for a long period.
      Thread.new do
        while true do
          sleep(60)
          @client.service_instance.current_time
        end
      end

      # HACK: finalizer not getting called, so we'll rely on at_exit
      at_exit { @client.logout }
    end

    def create_stemcell(image, _)
      with_thread_name("create_stemcell(#{image}, _)") do
        result = nil
        Dir.mktmpdir do |temp_dir|
          @logger.info("Extracting stemcell to: #{temp_dir}")
          output = `tar -C #{temp_dir} -xzf #{image} 2>&1`
          raise "Corrupt image, tar exit status: #{$?.exitstatus} output: #{output}" if $?.exitstatus != 0

          ovf_file = Dir.entries(temp_dir).find { |entry| File.extname(entry) == ".ovf" }
          raise "Missing OVF" if ovf_file.nil?
          ovf_file = File.join(temp_dir, ovf_file)

          name = "sc-#{generate_unique_name}"
          @logger.info("Generated name: #{name}")

          # TODO: make stemcell friendly version of the calls below
          cluster, datastore = @resources.get_resources
          @logger.info("Deploying to: #{cluster.mob} / #{datastore.mob}")

          import_spec_result = import_ovf(name, ovf_file, cluster.resource_pool, datastore.mob)
          lease = obtain_nfc_lease(cluster.resource_pool, import_spec_result.import_spec,
                                   cluster.datacenter.template_folder)
          @logger.info("Waiting for NFC lease")
          state = wait_for_nfc_lease(lease)
          raise "Could not acquire HTTP NFC lease" unless state == Vim::HttpNfcLease::State::READY

          @logger.info("Uploading")
          vm = upload_ovf(ovf_file, lease, import_spec_result.file_item)
          result = name

          @logger.info("Removing NICs")
          devices = client.get_property(vm, Vim::VirtualMachine, "config.hardware.device", :ensure_all => true)
          config = Vim::Vm::ConfigSpec.new
          config.device_change = []

          nics = devices.select { |device| device.kind_of?(Vim::Vm::Device::VirtualEthernetCard) }
          nics.each do |nic|
            nic_config = create_delete_device_spec(nic)
            config.device_change << nic_config
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
        Bosh::ThreadPool.new(:max_threads => 32, :logger => @logger).wrap do |pool|
          @resources.datacenters.each_value do |datacenter|
            @logger.info("Looking for stemcell replicas in: #{datacenter.name}")
            templates = client.get_property(datacenter.template_folder, Vim::Folder, "childEntity", :ensure_all => true)
            template_properties = client.get_properties(templates, Vim::VirtualMachine, ["name"])
            template_properties.each_value do |properties|
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
        end
      end
    end

    def disk_spec(vm_disk, persistent_disks)
      disks = []
      disks << {"size" => vm_disk, "persistent" => false}

      persistent_disks ||= {}
      persistent_disks.each do |disk_id|
        disk = Models::Disk[disk_id]
        disks << {"size" => disk.size, "persistent" => true, "datacenter" => disk.datacenter, "datastore" => disk.datastore}
      end
      disks
    end

    def create_vm(agent_id, stemcell, resource_pool, networks, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        memory = resource_pool["ram"]
        disk = resource_pool["disk"]
        cpu = resource_pool["cpu"]

        # Make sure number of cores is a power of 2. kb.vmware.com/kb/2003484
        if cpu & cpu - 1 != 0
          raise "Number of vCPUs: #{cpu} is not a power of 2."
        end

        disks = disk_spec(disk, disk_locality)
        cluster, datastore = @resources.get_resources(memory, disks)

        name = "vm-#{generate_unique_name}"
        @logger.info("Creating vm:: #{name} on #{cluster.mob} stored in #{datastore.mob}")

        replicated_stemcell_vm = replicate_stemcell(cluster, datastore, stemcell)
        replicated_stemcell_properties = client.get_properties(replicated_stemcell_vm, Vim::VirtualMachine,
                                                               ["config.hardware.device", "snapshot"],
                                                               :ensure_all => true)

        devices = replicated_stemcell_properties["config.hardware.device"]
        snapshot = replicated_stemcell_properties["snapshot"]

        config = Vim::Vm::ConfigSpec.new(:memory_mb => memory, :num_cpus => cpu)
        config.device_change = []

        system_disk = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualDisk) }
        pci_controller = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualPCIController) }

        file_name = "[#{datastore.name}] #{name}/ephemeral_disk.vmdk"
        ephemeral_disk_config = create_disk_config_spec(datastore.mob, file_name, system_disk.controller_key, disk,
                                                        :create => true)
        config.device_change << ephemeral_disk_config

        dvs_index = {}
        networks.each_value do |network|
          v_network_name = network["cloud_properties"]["name"]
          network_mob = client.find_by_inventory_path([cluster.datacenter.name, "network", v_network_name])
          nic_config = create_nic_config_spec(v_network_name, network_mob, pci_controller.key, dvs_index)
          config.device_change << nic_config
        end

        nics = devices.select { |device| device.kind_of?(Vim::Vm::Device::VirtualEthernetCard) }
        nics.each do |nic|
          nic_config = create_delete_device_spec(nic)
          config.device_change << nic_config
        end

        fix_device_unit_numbers(devices, config.device_change)

        @logger.info("Cloning vm: #{replicated_stemcell_vm} to #{name}")

        task = clone_vm(replicated_stemcell_vm, name, cluster.datacenter.vm_folder, cluster.resource_pool,
                        :datastore => datastore.mob, :linked => true, :snapshot => snapshot.current_snapshot,
                        :config => config)
        vm = client.wait_for_task(task)

        begin
          upload_file(cluster.datacenter.name, datastore.name, "#{name}/env.iso", "")

          vm_properties = client.get_properties(vm, Vim::VirtualMachine, ["config.hardware.device"], :ensure_all => true)
          devices = vm_properties["config.hardware.device"]

          # Configure the ENV CDROM
          config = Vim::Vm::ConfigSpec.new
          config.device_change = []
          file_name = "[#{datastore.name}] #{name}/env.iso"
          cdrom_change = configure_env_cdrom(datastore.mob, devices, file_name)
          config.device_change << cdrom_change
          client.reconfig_vm(vm, config)

          network_env = generate_network_env(devices, networks, dvs_index)
          disk_env = generate_disk_env(system_disk, ephemeral_disk_config.device)
          env = generate_agent_env(name, vm, agent_id, network_env, disk_env)
          env["env"] = environment
          @logger.info("Setting VM env: #{env.pretty_inspect}")

          location = get_vm_location(vm, :datacenter => cluster.datacenter.name,
                                         :datastore => datastore.name,
                                         :vm => name)
          set_agent_env(vm, location, env)

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
                                           :ensure => ["config.hardware.device"])

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

    # TODO add option to force hard/soft reboot
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
        devices = client.get_property(vm, Vim::VirtualMachine, "config.hardware.device", :ensure_all => true)
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

        location = get_vm_location(vm, :datacenter => datacenter_name)
        env = get_current_agent_env(location)
        @logger.debug("Reading current agent env: #{env.pretty_inspect}")

        devices = client.get_property(vm, Vim::VirtualMachine, "config.hardware.device", :ensure_all => true)
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
                                          :ensure_all => true)

      # Get the cluster that the vm's host belongs to.
      cluster = @client.get_properties(properties["parent"], Vim::ClusterComputeResource, "name")

      # Get the datastores that are accessible to the vm's host.
      datastores_accessible = []
      properties["datastore"].each { |store|
        ds = @client.get_properties(store, Vim::Datastore, "info", :ensure_all => true)
        datastores_accessible << ds["info"].name
      }

      {"cluster" => cluster["name"], "datastores" => datastores_accessible}
    end

    def find_persistent_datastore(datacenter_name, host_info, disk_size)
      # Find datastore
      datastore = @resources.find_persistent_datastore(datacenter_name, host_info["cluster"], disk_size)

      if datastore.nil?
        raise Bosh::Clouds::NoDiskSpace.new(true), "Not enough persistent space on cluster #{host_info["cluster"]}, #{disk_size}"
      end

      # Sanity check, verify that the vm's host can access this datastore
      unless host_info["datastores"].include?(datastore.name)
        raise "Datastore not accessible to host, #{datastore.name}, #{host_info["datastores"]}"
      end
      datastore
    end

    def attach_disk(vm_cid, disk_cid)
      with_thread_name("attach_disk(#{vm_cid}, #{disk_cid})") do
        @logger.info("Attaching disk: #{disk_cid} on vm: #{vm_cid}")
        disk = Models::Disk[disk_cid]
        raise "Disk not found: #{disk_cid}" if disk.nil?

        vm = get_vm_by_cid(vm_cid)

        datacenter = client.find_parent(vm, Vim::Datacenter)
        datacenter_name = client.get_property(datacenter, Vim::Datacenter, "name")

        vm_properties = client.get_properties(vm, Vim::VirtualMachine, "config.hardware.device", :ensure_all => true)
        host_info = get_vm_host_info(vm)
        persistent_datastore = nil

        create_disk = false
        if disk.path
          if disk.datacenter == datacenter_name &&
                  @resources.validate_persistent_datastore(datacenter_name, disk.datastore) &&
                  host_info["datastores"].include?(disk.datastore)
            # Looks like we have a valid persistent data store

            @logger.info("Disk already in the right datastore #{datacenter_name} #{disk.datastore}")
            persistent_datastore = @resources.get_persistent_datastore(datacenter_name, host_info["cluster"],
                                                                       disk.datastore)
          else
            @logger.info("Disk needs to move from #{datacenter_name} #{disk.datastore}")

            # Find the destination datastore
            persistent_datastore = find_persistent_datastore(datacenter_name, host_info, disk.size)

            # Need to move disk to right datastore
            source_datacenter = client.find_by_inventory_path(disk.datacenter)
            source_path = disk.path
            datacenter_disk_path = @resources.datacenters[disk.datacenter].disk_path

            destination_path = "[#{persistent_datastore.name}] #{datacenter_disk_path}/#{disk.id}"
            @logger.info("Moving #{disk.datacenter}/#{source_path} to #{datacenter_name}/#{destination_path}")

            if @copy_disks
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
          disk.path = "[#{disk.datastore}] #{datacenter_disk_path}/#{disk.id}"
          disk.save
          create_disk = true
        end

        devices = vm_properties["config.hardware.device"]
        system_disk = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualDisk) }

        vmdk_path = "#{disk.path}.vmdk"
        attached_disk_config = create_disk_config_spec(persistent_datastore.mob, vmdk_path,
                                                       system_disk.controller_key, disk.size.to_i,
                                                       :create => create_disk, :independent => true)
        config = Vim::Vm::ConfigSpec.new
        config.device_change = []
        config.device_change << attached_disk_config
        fix_device_unit_numbers(devices, config.device_change)

        location = get_vm_location(vm, :datacenter => datacenter_name)
        env = get_current_agent_env(location)
        @logger.info("Reading current agent env: #{env.pretty_inspect}")
        env["disks"]["persistent"][disk.id.to_s] = attached_disk_config.device.unit_number
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
        disk = Models::Disk[disk_cid]
        raise "Disk not found: #{disk_cid}" if disk.nil?

        vm = get_vm_by_cid(vm_cid)

        devices = client.get_property(vm, Vim::VirtualMachine, "config.hardware.device", :ensure_all => true)

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
        env["disks"]["persistent"].delete(disk.id.to_s)
        @logger.info("Updating agent env to: #{env.pretty_inspect}")
        set_agent_env(vm, location, env)
        @logger.info("Detaching disk")
        client.reconfig_vm(vm, config)

        # detach-disk is async and task completion does not necessarily mean
        # that changes have been applied to VC side. Query VC until we confirm
        # that the change has been applied. This is a known issue for vsphere 4.
        # Fixed in vsphere 5.
        5.times do
          devices = client.get_property(vm, Vim::VirtualMachine, "config.hardware.device", :ensure_all => true)
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
        disk.size = size
        disk.save
        @logger.info("Created disk: #{disk.pretty_inspect}")
        disk.id.to_s
      end
    end

    def delete_disk(disk_cid)
      with_thread_name("delete_disk(#{disk_cid})") do
        @logger.info("Deleting disk: #{disk_cid}")
        disk = Models::Disk[disk_cid]
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
      # TODO: still needed? what does it verify? cloud properties? should be replaced by normalize cloud properties?
    end

    def get_vm_by_cid(vm_cid)
      # TODO: fix when we go to multiple DCs
      datacenter = @resources.datacenters.values.first
      vm = client.find_by_inventory_path([datacenter.name, "vm", datacenter.vm_folder_name, vm_cid])
      raise Bosh::Clouds::VMNotFound, "VM `#{vm_cid}' not found" if vm.nil?
      vm
    end

    def replicate_stemcell(cluster, datastore, stemcell)
      stemcell_vm = client.find_by_inventory_path([cluster.datacenter.name, "vm",
                                                   cluster.datacenter.template_folder_name, stemcell])
      raise "Could not find stemcell: #{stemcell}" if stemcell_vm.nil?
      stemcell_datastore = client.get_property(stemcell_vm, Vim::VirtualMachine, "datastore", :ensure_all => true)

      if stemcell_datastore != datastore.mob
        @logger.info("Stemcell lives on a different datastore, looking for a local copy of: #{stemcell}.")
        local_stemcell_name    = "#{stemcell} / #{datastore.mob.__mo_id__}"
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
      env.merge!(@agent_properties)
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
                                              :ensure_all => true)
        vm_name = vm_properties["name"]

        unless datastore_name
          devices = vm_properties["config.hardware.device"]
          datastore = get_primary_datastore(devices)
          datastore_name = client.get_property(datastore, Vim::Datastore, "name")
        end
      end

      {:datacenter => datacenter_name, :datastore =>datastore_name, :vm =>vm_name}
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
      devices = client.get_property(vm, Vim::VirtualMachine, "config.hardware.device", :ensure_all => true)
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

    def fetch_file(datacenter_name, datastore_name, path)
      retry_block do
        url = "https://#{@vcenter["host"]}/folder/#{path}?dcPath=#{URI.escape(datacenter_name)}" +
        "&dsName=#{URI.escape(datastore_name)}"

        response = @rest_client.get(url)

        if response.code < 400
          response.body
        elsif response.code == 404
          nil
        else
          raise "Could not fetch file: #{url}, status code: #{response.code}"
        end
      end
    end

    def upload_file(datacenter_name, datastore_name, path, contents)
      retry_block do
        url = "https://#{@vcenter["host"]}/folder/#{path}?dcPath=#{URI.escape(datacenter_name)}" +
              "&dsName=#{URI.escape(datastore_name)}"
        response = @rest_client.put(url, contents, {"Content-Type" => "application/octet-stream",
                                                    "Content-Length" => contents.length})

        raise "Could not upload file: #{url}, status code: #{response.code}" unless response.code < 400
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

    def take_snapshot(vm, name)
      vm.create_snapshot(name, nil, false, false)
    end

    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
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
        portgroup_properties = client.get_properties(network, Vim::Dvs::DistributedVirtualPortgroup,
                                                     ["config.key", "config.distributedVirtualSwitch"],
                                                     :ensure_all => true)

        switch = portgroup_properties["config.distributedVirtualSwitch"]
        switch_uuid = client.get_property(switch, Vim::DistributedVirtualSwitch, "uuid", :ensure_all => true)

        port = Vim::Dvs::PortConnection.new
        port.switch_uuid = switch_uuid
        port.portgroup_key = portgroup_properties["config.key"]

        backing_info = Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo.new
        backing_info.port = port

        dvs_index[port.portgroup_key] = v_network_name
      else
        backing_info = Vim::Vm::Device::VirtualEthernetCard::NetworkBackingInfo.new
        backing_info.device_name = v_network_name
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

    def create_edit_device_spec(device)
      device_config_spec = Vim::Vm::Device::VirtualDeviceSpec.new
      device_config_spec.device = device
      device_config_spec.operation = Vim::Vm::Device::VirtualDeviceSpec::Operation::EDIT
      device_config_spec
    end

    def fix_device_unit_numbers(devices, device_changes)
      max_unit_numbers = {}
      devices.each do |device|
        if device.controller_key
          max_unit_number = max_unit_numbers[device.controller_key]
          if max_unit_number.nil? || max_unit_number < device.unit_number
            max_unit_numbers[device.controller_key] = device.unit_number
          end
        end
      end

      device_changes.each do |device_change|
        device = device_change.device
        if device.controller_key && device.unit_number.nil?
          max_unit_number = max_unit_numbers[device.controller_key] || 0
          device.unit_number = max_unit_number + 1
          max_unit_numbers[device.controller_key] = device.unit_number
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

      @client.service_content.ovf_manager.create_import_spec(ovf_descriptor, resource_pool,
                                                             datastore, import_spec_params)
    end

    def obtain_nfc_lease(resource_pool, import_spec, folder)
      resource_pool.import_vapp(import_spec, folder, nil)
    end

    def wait_for_nfc_lease(lease)
      loop do
        state = client.get_property(lease, Vim::HttpNfcLease, "state")
        unless state == Vim::HttpNfcLease::State::INITIALIZING
          return state
        end
        sleep(1.0)
      end
    end

    def upload_ovf(ovf, lease, file_items)
      info = client.get_property(lease, Vim::HttpNfcLease, "info", :ensure_all => true)
      lease_updater = LeaseUpdater.new(client, lease)

      info.device_url.each do |device_url|
        device_key = device_url.import_key
        file_items.each do |file_item|
          if device_key == file_item.device_id
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

    def wait_until_off(vm, timeout)
        started = Time.now
        loop do
          power_state = client.get_property(vm, Vim::VirtualMachine, "runtime.powerState")
          break if power_state == Vim::VirtualMachine::PowerState::POWERED_OFF
          raise TimeoutException if Time.now - started > timeout
          sleep(1.0)
        end
    end

    def delete_all_vms
      Bosh::ThreadPool.new(:max_threads => 32, :logger => @logger).wrap do |pool|
        index = 0

        @resources.datacenters.each_value do |datacenter|
          vm_folder_path = [datacenter.name, "vm", datacenter.vm_folder_name]
          vm_folder = client.find_by_inventory_path(vm_folder_path)
          vms = client.get_managed_objects(Vim::VirtualMachine, :root => vm_folder)
          next if vms.empty?

          vm_properties = client.get_properties(vms, Vim::VirtualMachine, ["name"])

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
      end
    end

  end
end
