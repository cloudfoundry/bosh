$: << File.expand_path(File.dirname(__FILE__))
$: << File.expand_path(File.dirname(__FILE__) + "/client")

require "digest/sha1"
require "fileutils"
require "client"
require "config"
require "logger"
require "uuidtools"
require "yajl"
require "const"
require "util"
require "config"
require "thread"

module VCloudCloud

  class Cloud

    class NotImplemented < StandardError; end

    def initialize(options)
      @logger = Bosh::Clouds::Config.logger
      @logger.debug("Input cloud options: #{options.inspect}")

      @agent_properties = options["agent"]
      rest_log_filename = File.join(File.dirname(@logger.instance_eval { @logdev }.dev.path), "rest")
      log_file = File.open(rest_log_filename, "w")
      log_file.sync = true
      @rest_logger = Logger.new(log_file || STDOUT)
      @rest_logger.level = @logger.level
      @rest_logger.formatter = @logger.formatter
      def @rest_logger.<<(str)
        self.debug(str.chomp)
      end

      vcds = options["vcds"]
      raise "Invalid number of VCDs" unless vcds.size == 1
      @vcd = vcds[0]

      finalize_options
      @control = @vcd["control"]
      @retries = @control["retries"]
      Config.configure({ 'logger' => @logger, 'rest_logger' => @rest_logger,
        'rest_throttle' => @vcd["control"]["rest_throttle"] })
      @logger.info("VCD cloud options: #{options.inspect}")

      @client_lock = Mutex.new

      at_exit { destroy_client() }
    end

    def client()
      @client_lock.synchronize {
        if @client.nil?
          create_client()
        else
          begin
            @client.get_ovdc
            @client
          rescue => ex
            log_exception("validate, creating new session.", ex)
            create_client()
          end
        end
      }
    end

    def create_stemcell(image, _)
      @client = client

      with_thread_name("create_stemcell(#{image}, _)") do
        @logger.debug("create_stemcell #{image} #{_}")
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

          @logger.info("Uploading #{ovf_file}")
          result = @client.upload_vapp_template(name, temp_dir).urn
        end

        @logger.info("Stemcell created as catalog vApp with ID \"#{result}\".")
        result
      end
    end

    def delete_stemcell(catalog_vapp_id)
      @client = client

      with_thread_name("delete_stemcell(#{catalog_vapp_id})") do
        @logger.debug("delete_stemcell #{catalog_vapp_id}")

        # shadow VMs (stemcell replicas) get deleted serially,
        # and upon failure to delete they must be deleted manually
        # from VCD "stranded items"
        @client.delete_catalog_vapp(catalog_vapp_id)
      end
    end

    def create_vm(agent_id, catalog_vapp_id, resource_pool, networks, disk_locality = nil, environment = {})
      @client = client

      with_thread_name("create_vm(#{agent_id}, ...)") do
        Util.retry_operation("create_vm(#{agent_id}, ...)", @retries['cpi'], @control['backoff']) do
          @logger.info("Creating VM: #{agent_id}")
          @logger.debug("resource_pool: #{resource_pool.inspect}")
          @logger.debug("networks: #{networks.inspect}")

          locality = independent_disks(disk_locality)
          desc = @vcd["entities"]["description"]

          @logger.debug("Instantiating vApp: #{agent_id} in #{@vcd["entities"]["virtual_datacenter"]}")
          vapp = @client.instantiate_vapp_template(catalog_vapp_id, agent_id, desc, locality)
          @logger.debug("Instantiated vApp: id=#{vapp.urn} name=#{agent_id} name=#{vapp.name}")

          vm = get_vm(vapp)

          begin
            ram_mb = Integer(resource_pool["ram"])
            cpu = Integer(resource_pool["cpu"])
            disk_mb = Integer(resource_pool["disk"])

            disks = vm.hardware_section.hard_disks
            @logger.debug("disks = #{disks.inspect}")
            raise "Invalid number of vApp hard disks" unless disks.size == 1
            system_disk = disks[0]
            disks_previous = Array.new(disks)

            add_vapp_networks(vapp, networks)

            @logger.info("Reconfiguring VM hardware: #{agent_id}, #{ram_mb} MB RAM, #{cpu} CPU, #{disk_mb} MB disk, #{desc}.")
            @client.reconfigure_vm(vm) do |v|
              v.name = agent_id
              v.description = desc
              v.change_cpu_count(cpu)
              v.change_memory(ram_mb)
              v.add_hard_disk(disk_mb)
              v.delete_nic(*vm.hardware_section.nics)
              add_vm_nics(v, networks)
            end

            delete_vapp_networks(vapp, networks)

            vapp, vm = get_vapp_vm_by_vapp_id(vapp.urn)
            ephemeral_disk = get_newly_added_disk(vm, disks_previous)

            # prepare guest customization settings
            network_env = generate_network_env(vm.hardware_section.nics, networks)
            disk_env = generate_disk_env(system_disk, ephemeral_disk)
            env = generate_agent_env(agent_id, vm, agent_id, network_env, disk_env)
            env["env"] = environment
            @logger.info("Setting VM env: #{vapp.urn} #{env.inspect}")
            set_agent_env(vm, env)

            @logger.info("Powering on vApp: #{vapp.urn}")
            @client.power_on_vapp(vapp)
          rescue => ex
            log_exception("create vApp", ex)
            delete_vm(vapp.urn)
            raise ex
          end

          @logger.info("Created VM: #{agent_id} as #{vapp.urn}")
          vapp.urn
        end
      end
    end

    def delete_vm(vapp_id)
      @client = client

      with_thread_name("delete_vm(#{vapp_id}, ...)") do
        Util.retry_operation("delete_vm(#{vapp_id}, ...)", @retries['cpi'], @control['backoff']) do
          @logger.info("Deleting vApp: #{vapp_id}")
          begin
            vapp = @client.get_vapp(vapp_id)
            vm = get_vm(vapp)
            vm_name = vm.name

            begin
              @client.power_off_vapp(vapp)
            rescue VCloudCloud::Client::VappSuspended => e
              @client.discard_suspended_state_vapp(vapp)
              @client.power_off_vapp(vapp)
            end
            @client.delete_vapp(vapp) if @vcd['debug']['delete_vapp'] == true
            @logger.info("Deleting ISO #{vm_name}")
            @client.delete_catalog_media(vm_name) if @vcd['debug']['delete_vapp'] == true
          rescue => ex
            log_exception("delete vApp #{vapp_id}", ex)
            raise ex
          end
          @logger.info("Deleted vApp: #{vapp_id}")
        end
      end
    end

    def reboot_vm(vapp_id)
      @client = client

      with_thread_name("reboot_vm(#{vapp_id}, ...)") do
        Util.retry_operation("reboot_vm(#{vapp_id}, ...)", @retries['cpi'], @control['backoff']) do
          @logger.info("Rebooting vApp: #{vapp_id}")
          begin
            vapp = @client.get_vapp(vapp_id)
            begin
              @client.reboot_vapp(vapp)
            rescue VCloudCloud::Client::VappPoweredOff => e
              @client.power_on_vapp(vapp)
            rescue VCloudCloud::Client::VappSuspended => e
              @client.discard_suspended_state_vapp(vapp)
              @client.power_on_vapp(vapp)
            end
          rescue => ex
            log_exception("reboot vApp #{vapp_id}", ex)
            raise ex
          end
          @logger.info("Rebooted vApp: #{vapp_id}")
        end
      end
    end

    def configure_networks(vapp_id, networks)
      @client = client

      with_thread_name("configure_networks(#{vapp_id}, ...)") do
        Util.retry_operation("configure_networks(#{vapp_id}, ...)", @retries['cpi'], @control['backoff']) do
          @logger.info("Reconfiguring vApp networks: #{vapp_id}")
          begin
            vapp, vm = get_vapp_vm_by_vapp_id(vapp_id)
            @logger.debug("Powering off #{vapp.name}.")
            begin
              @client.power_off_vapp(vapp)
            rescue VCloudCloud::Client::VappSuspended => e
              @client.discard_suspended_state_vapp(vapp)
              @client.power_off_vapp(vapp)
            end

            add_vapp_networks(vapp, networks)
            @client.reconfigure_vm(vm) do |v|
              v.delete_nic(*vm.hardware_section.nics)
              add_vm_nics(v, networks)
            end
            delete_vapp_networks(vapp, networks)

            vapp, vm = get_vapp_vm_by_vapp_id(vapp_id)
            env = get_current_agent_env(vm)
            env["networks"] = generate_network_env(vm.hardware_section.nics, networks)
            @logger.debug("Updating agent env to: #{env.inspect}")
            set_agent_env(vm, env)

            @logger.debug("Powering #{vapp.name} back on.")
            @client.power_on_vapp(vapp)
          rescue => ex
            log_exception("configure vApp networks: #{vapp}", ex)
            raise ex
          end
          @logger.info("Configured vApp networks: #{vapp}")
        end
      end
    end

    def attach_disk(vapp_id, disk_id)
      @client = client

      with_thread_name("attach_disk(#{vapp_id} #{disk_id})") do
        Util.retry_operation("attach_disk(#{vapp_id}, #{disk_id})", @retries['cpi'], @control['backoff']) do
          @logger.info("Attaching disk: #{disk_id} on vm: #{vapp_id}")

          vapp, vm = get_vapp_vm_by_vapp_id(vapp_id)
          # vm.hardware_section will change, save current state of disks
          disks_previous = Array.new(vm.hardware_section.hard_disks)

          disk = @client.get_disk(disk_id)
          @client.attach_disk(disk, vm)

          vapp, vm = get_vapp_vm_by_vapp_id(vapp_id)
          persistent_disk = get_newly_added_disk(vm, disks_previous)

          env = get_current_agent_env(vm)
          env["disks"]["persistent"][disk_id] = persistent_disk.disk_id
          @logger.info("Updating agent env to: #{env.inspect}")
          set_agent_env(vm, env)

          @logger.info("Attached disk: #{disk_id} on vm: #{vapp_id}")
        end
      end
    end

    def detach_disk(vapp_id, disk_id)
      @client = client

      with_thread_name("detach_disk(#{vapp_id} #{disk_id})") do
        Util.retry_operation("detach_disk(#{vapp_id}, #{disk_id})", @retries['cpi'], @control['backoff']) do
          @logger.info("Detaching disk: #{disk_id} from vm: #{vapp_id}")

          vapp, vm = get_vapp_vm_by_vapp_id(vapp_id)

          disk = @client.get_disk(disk_id)
          begin
            @client.detach_disk(disk, vm)
          rescue VCloudCloud::Client::VmSuspended => e
            @client.discard_suspended_state_vapp(vapp)
            @client.detach_disk(disk, vm)
          end

          env = get_current_agent_env(vm)
          env["disks"]["persistent"].delete(disk_id)
          @logger.info("Updating agent env to: #{env.inspect}")
          set_agent_env(vm, env)

          @logger.info("Detached disk: #{disk_id} on vm: #{vapp_id}")
        end
      end
    end

    def create_disk(size_mb, vm_locality = nil)
      @client = client

      with_thread_name("create_disk(#{size_mb}, vm_locality)") do
        Util.retry_operation("create_disk(#{size_mb}, vm_locality)", @retries['cpi'], @control['backoff']) do
          @logger.info("Create disk: #{size_mb}, #{vm_locality}")
          disk_name = "#{generate_unique_name}"
          disk = nil
          if vm_locality.nil?
            @logger.info("Creating disk: #{disk_name} #{size_mb}")
            disk = @client.create_disk(disk_name, size_mb)
          else
            # vm_locality => vapp_id
            vapp, vm = get_vapp_vm_by_vapp_id(vm_locality)
            @logger.info("Creating disk: #{disk_name} #{size_mb} #{vm.name}")
            disk = @client.create_disk(disk_name, size_mb, vm)
          end
          @logger.info("Created disk: #{disk_name} #{disk.urn} #{size_mb} #{vm_locality}")
          disk.urn
        end
      end
    end

    def delete_disk(disk_id)
      @client = client

      with_thread_name("delete_disk(#{disk_id})") do
        Util.retry_operation("delete_disk(#{disk_id})", @retries['cpi'], @control['backoff']) do
          @logger.info("Deleting disk: #{disk_id}")
          disk = @client.get_disk(disk_id)
          @client.delete_disk(disk)
          @logger.info("Deleted disk: #{disk_id}")
        end
      end
    end

    def validate_deployment(old_manifest, new_manifest)
      # There is TODO in vSphere CPI that questions the necessity of this method
      raise NotImplemented, "validate_deployment"
    end

    private

    def finalize_options
      @vcd['control'] = {} if  @vcd['control'].nil?
      @vcd['control']['retries'] = {} if  @vcd['control']['retries'].nil?
      @vcd['control']['retries']['default'] ||= RETRIES_DEFAULT
      @vcd['control']['retries']['upload_vapp_files'] ||= RETRIES_UPLOAD_VAPP_FILES
      @vcd['control']['retries']['cpi'] ||= RETRIES_CPI
      @vcd['control']['delay'] ||= DELAY
      @vcd['control']['time_limit_sec'] = {} if  @vcd['control']['time_limit_sec'].nil?
      @vcd['control']['time_limit_sec']['default'] ||= TIMELIMIT_DEFAULT
      @vcd['control']['time_limit_sec']['delete_vapp_template'] ||= TIMELIMIT_DELETE_VAPP_TEMPLATE
      @vcd['control']['time_limit_sec']['delete_vapp'] ||= TIMELIMIT_DELETE_VAPP
      @vcd['control']['time_limit_sec']['delete_media'] ||= TIMELIMIT_DELETE_MEDIA
      @vcd['control']['time_limit_sec']['instantiate_vapp_template'] ||= TIMELIMIT_INSTANTIATE_VAPP_TEMPLATE
      @vcd['control']['time_limit_sec']['power_on'] ||= TIMELIMIT_POWER_ON
      @vcd['control']['time_limit_sec']['power_off'] ||= TIMELIMIT_POWER_OFF
      @vcd['control']['time_limit_sec']['undeploy'] ||= TIMELIMIT_UNDEPLOY
      @vcd['control']['time_limit_sec']['process_descriptor_vapp_template'] ||= TIMELIMIT_PROCESS_DESCRIPTOR_VAPP_TEMPLATE
      @vcd['control']['time_limit_sec']['http_request'] ||= TIMELIMIT_HTTP_REQUEST
      @vcd['control']['backoff'] ||= BACKOFF
      @vcd['control']['rest_throttle'] = {} if  @vcd['control']['rest_throttle'].nil?
      @vcd['control']['rest_throttle']['min'] ||= REST_THROTTLE_MIN
      @vcd['control']['rest_throttle']['max'] ||= REST_THROTTLE_MAX
      @vcd['debug'] = {} if  @vcd['debug'].nil?
      @vcd['debug']['delete_vapp'] = DEBUG_DELETE_VAPP if @vcd['debug']['delete_vapp'].nil?
    end

    def create_client()
      url = @vcd["url"]
      @logger.debug("Create session to VCD cloud: #{url}")
      @rest_logger.debug("Session to VCD cloud: #{url}")

      @client = VCloudCloud::Client::Client.new(url, @vcd["user"], @vcd["password"],
        @vcd["entities"], @vcd["control"])

      @logger.info("Created session to VCD cloud: #{url}")

      @client
    end

    def destroy_client()
      url = @vcd["url"]
      @logger.debug("Destroy session to VCD cloud: #{url}")
      # TODO VCloudCloud::Client::Client should permit logout.
      @logger.info("Destroyed session to VCD cloud: #{url}")
    end

    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
    end

    def log_exception(op, ex)
      @logger.error("Failed to #{op}.")
      @logger.error(ex)
    end

    def generate_network_env(nics, networks)
      nic_net = {}
      nics.each do |nic|
        nic_net[nic.network] = nic
      end
      @logger.debug("nic_net #{nic_net.inspect}")

      network_env = {}
      networks.each do |network_name, network|
        network_entry = network.dup
        v_network_name = network["cloud_properties"]["name"]
        nic = nic_net[v_network_name]
        if nic.nil? then
          @logger.warn("Not generating network env for #{v_network_name}")
          next
        end
        network_entry["mac"] = nic.mac_address
        network_env[network_name] = network_entry
      end
      network_env
    end

    def generate_disk_env(system_disk, ephemeral_disk)
      {
        "system" => system_disk.disk_id,
        "ephemeral" => ephemeral_disk.disk_id,
        "persistent" => {}
      }
    end

    def generate_agent_env(name, vm, agent_id, networking_env, disk_env)
      vm_env = {
        "name" => name,
        "id" => vm.urn
      }

      env = {}
      env["vm"] = vm_env
      env["agent_id"] = agent_id
      env["networks"] = networking_env
      env["disks"] = disk_env
      env.merge!(@agent_properties)
      env
    end

    def get_current_agent_env(vm)
      env = @client.get_metadata(vm, @vcd["entities"]["vm_metadata_key"])
      @logger.info("Current agent env: #{env.inspect}")
      Yajl::Parser.parse(env)
    end

    def set_agent_env(vm, env)
      env_json = Yajl::Encoder.encode(env)
      @logger.debug("env.iso content #{env_json}")

      begin
        # Clear existing ISO if one exists.
        @logger.info("Ejecting ISO #{vm.name}")
        @client.eject_catalog_media(vm, vm.name)
        @logger.info("Deleting ISO #{vm.name}")
        @client.delete_catalog_media(vm.name)
      rescue => ex
        @logger.debug("No ISO to eject/delete before setting new agent env.")
        # Continue setting agent env...
      end

      # generate env iso, and insert into VM
      Dir.mktmpdir do |path|
        env_path = File.join(path, "env")
        iso_path = File.join(path, "env.iso")
        File.open(env_path, "w") { |f| f.write(env_json) }
        output = `genisoimage -o #{iso_path} #{env_path} 2>&1`
        raise "#{$?.exitstatus} -#{output}" if $?.exitstatus != 0

        @client.set_metadata(vm, @vcd["entities"]["vm_metadata_key"], env_json)

        storage_profiles = @client.get_ovdc.storage_profiles || []
        media_storage_profile = storage_profiles.find { |sp| sp['name'] == @vcd["entities"]["media_storage_profile"] }
        @logger.info("Uploading and inserting ISO #{iso_path} as #{vm.name} to \"#{media_storage_profile.inspect}\"")
        @client.upload_catalog_media(vm.name, iso_path, media_storage_profile)
        @client.insert_catalog_media(vm, vm.name)
        @logger.info("Uploaded and inserted ISO #{iso_path} as #{vm.name}")
      end
    end

    def delete_vapp_networks(vapp, exclude_nets)
      exclude = exclude_nets.map {|k,v| v["cloud_properties"]["name"]}.uniq
      @client.delete_networks(vapp, exclude)
      @logger.debug("Deleted vApp #{vapp.name} networks excluding #{exclude.inspect}.")
    end

    def add_vapp_networks(vapp, networks)
      @logger.debug("Networks to add: #{networks.inspect}")
      ovdc = @client.get_ovdc
      accessible_org_networks = ovdc.available_networks
      @logger.debug("Accessible Org networks: #{accessible_org_networks.inspect}")

      networks.map {|k,v| v["cloud_properties"]["name"]}.uniq.each do |configured_network|
        @logger.debug("Adding configured network: \"#{configured_network}\"")
        org_net = accessible_org_networks.find { |n| n['name'] == configured_network }
        raise "Configured network \"#{configured_network}\" is not accessible to VDC \"#{ovdc.name}\"." if org_net.nil?
        @logger.debug("Adding configured network: \"#{configured_network}\" => Org net: \"#{org_net.inspect}\" to vApp \"#{vapp.name}\".")
        @client.add_network(vapp, org_net)
        @logger.debug("Added vApp network: \"#{configured_network}\".")
      end
      @logger.debug("Accessible configured networks added: \"#{networks.inspect}\".")
    end

    def add_vm_nics(v, networks)
      nic_index = 0
      networks.each_value do |network|
        if nic_index+1 >= VM_NIC_LIMIT then
          @logger.warn("Max number of NICs reached")
          break
        end
        configured_network = network["cloud_properties"]["name"]
        @logger.info("Adding NIC with IP address #{network["ip"]}.")
        v.add_nic(nic_index, configured_network, Client::Xml::IP_ADDRESSING_MODE[:MANUAL], network["ip"])
        v.connect_nic(nic_index, configured_network, Client::Xml::IP_ADDRESSING_MODE[:MANUAL], network["ip"])
        nic_index += 1
      end
      @logger.info("NICs added to #{v.name} and connected to network: #{networks.inspect}")
    end

    def get_vm(vapp)
      vms = vapp.vms
      raise "Invalid number of vApp VMs" unless vms.size == 1
      vms[0]
    end

    def get_vapp_vm_by_vapp_id(id)
      vapp = @client.get_vapp(id)
      [vapp, get_vm(vapp)]
    end

    def get_newly_added_disk(vm, disks_previous)
      disks_current = vm.hardware_section.hard_disks
      newly_added = disks_current - disks_previous

      if newly_added.size != 1
        @logger.debug("Previous disks in #{vapp_id}: #{disks_previous.inspect} ")
        @logger.debug("Current disks in #{vapp_id}:  #{disks_current.inspect}")
        raise "Expecting #{disks_previous.size + 1} disks, found #{disks_current.size}"
      end

      @logger.info("Newly added disk: #{newly_added[0]}")
      newly_added[0]
    end

    def independent_disks(disk_locality)
        disk_locality ||= []
        @logger.info("Instantiate vApp accessible to disks: #{disk_locality.join(',')}")
        disks = []
        disk_locality.each do |disk_id|
          disks << @client.get_disk(disk_id)
        end
        disks
    end

  end
end
