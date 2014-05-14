module VSphereCloud
  class AgentEnv
    include VimSdk
    include RetryBlock

    def initialize(cpi, client, file_provider, config, logger)
      @cpi = cpi
      @client = client
      @file_provider = file_provider
      @config = config
      @logger = logger
    end

    def get_current_env(location)
      contents = @file_provider.fetch_file(location[:datacenter], location[:datastore], "#{location[:vm]}/env.json")
      contents ? JSON.load(contents) : nil
    end

    def set_env(vm, location, env)
      if @config.datacenter_srm
        set_vmdk_content(vm, location, env)
      else
        set_cdrom_content(vm, location, env)
      end
    end

    def configure_vm_cdrom(cluster, datastore, name, vm, devices)
      if @config.datacenter_srm
        @file_provider.upload_file(cluster.datacenter.name, datastore.name, "#{name}/env.vmdk", '')
        return
      end

      # Configure the ENV CDROM
      @file_provider.upload_file(cluster.datacenter.name, datastore.name, "#{name}/env.iso", '')
      config = Vim::Vm::ConfigSpec.new
      config.device_change = []
      file_name = "[#{datastore.name}] #{name}/env.iso"
      cdrom_change = configure_env_cdrom(datastore.mob, devices, file_name)
      config.device_change << cdrom_change
      @client.reconfig_vm(vm, config)
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

    private

    def set_cdrom_content(vm, location, env)
      @logger.info('Setting env from cdrom')
      env_json = JSON.dump(env)

      connect_cdrom(vm, false)
      @file_provider.upload_file(location[:datacenter], location[:datastore], "#{location[:vm]}/env.json", env_json)
      @file_provider.upload_file(location[:datacenter], location[:datastore], "#{location[:vm]}/env.iso", generate_env_iso(env_json))
      connect_cdrom(vm, true)
    end

    def connect_cdrom(vm, connected = true)
      devices = @client.get_property(vm, Vim::VirtualMachine, 'config.hardware.device', ensure_all: true)
      cdrom = devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualCdrom) }

      if cdrom.connectable.connected != connected
        cdrom.connectable.connected = connected
        config = Vim::Vm::ConfigSpec.new
        config.device_change = [create_edit_device_spec(cdrom)]
        @client.reconfig_vm(vm, config)
      end
    end

    def generate_env_iso(env)
      Dir.mktmpdir do |path|
        env_path = File.join(path, 'env')
        iso_path = File.join(path, 'env.iso')
        File.open(env_path, 'w') { |f| f.write(env) }
        output = `#{genisoimage} -o #{iso_path} #{env_path} 2>&1`
        raise "#{$?.exitstatus} -#{output}" if $?.exitstatus != 0
        File.open(iso_path, 'r') { |f| f.read }
      end
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

    def find_bin(bin_path, bin)
      exe = File.join(bin_path, bin)
      return exe if File.exists?(exe)
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exe = File.join(path, bin)
        return exe if File.exists?(exe)
      end

      fail "Unable to find #{bin} in either #{bin_path} or system PATH"
    end

    def genisoimage
      @genisoimage ||= which(%w{genisoimage mkisofs})
    end

    def qemu_img
      @qemu_img ||= which(['qemu-img'])
    end

    def create_edit_device_spec(device)
      device_config_spec = Vim::Vm::Device::VirtualDeviceSpec.new
      device_config_spec.device = device
      device_config_spec.operation = Vim::Vm::Device::VirtualDeviceSpec::Operation::EDIT
      device_config_spec
    end

    def generate_vmdk_iso(env)
      path = Dir.mktmpdir
      env_path = File.join(path, 'env')
      iso_path = File.join(path, 'env.iso')
      File.open(env_path, 'w') { |f| f.write(env) }

      # HACK: Write a dummy file to make iso file exceed 1 MB
      # Because SRM needs at least 1 MB to replicate a disk
      File.open(File.join(path, 'env_dummy'), 'w') do |f|
        193000.times do |i|
          f.write(i)
        end
      end

      output = `#{genisoimage} -o #{iso_path} #{env_path}* 2>&1`
      raise "#{$?.exitstatus} -#{output}" if $?.exitstatus != 0
      path
    end

    def upload_vmdk_file(location, local_vmdk_file_dir)
      @file_provider.upload_file(location[:datacenter],
                                 location[:datastore],
                                 "#{location[:vm]}/env.vmdk",
                                 File.open(File.join(local_vmdk_file_dir, 'env.vmdk'), 'r') { |f| f.read })

      @file_provider.upload_file(location[:datacenter],
                                 location[:datastore],
                                 "#{location[:vm]}/env-flat.vmdk",
                                 File.open(File.join(local_vmdk_file_dir, 'env-flat.vmdk'), 'r') { |f| f.read })
    end

    def convert_iso_to_vmdk(tmp_dir)
      iso_file = File.join(tmp_dir, 'env.iso')
      fail "ISO file #{iso_file} does not exist!" if !File.exists?(iso_file)
      output = `#{qemu_img} convert -O vmdk #{iso_file} #{File.join(tmp_dir, 'env_source.vmdk')} 2>&1`
      fail "#{$?.exitstatus} -#{output}" if $?.exitstatus != 0
    end

    def convert_vmdk_to_esx_type(tmp_dir)
      env_source_vmdk = File.join(tmp_dir, 'env_source.vmdk')
      fail "ENV source vmdk file #{env_source_vmdk} does not exist!" if !File.exists?(env_source_vmdk)
      target_vmdk_file = File.join(tmp_dir, 'env.vmdk')
      [target_vmdk_file, File.join(tmp_dir, 'env-flat.vmdk')].each do |f|
        File.delete(f) if File.exists?(f)
      end

      module_dir = (`ls -d /lib/modules/3.*-virtual | tail -1`).strip
      vdiskmanager = find_bin("#{module_dir}/vdiskmanager/bin", 'vmware-vdiskmanager')
      output = `#{vdiskmanager} -r #{env_source_vmdk} -t 4 #{target_vmdk_file} 2>&1`
      fail "#{$?.exitstatus} -#{output}" if $?.exitstatus != 0
    end

    def set_vmdk_content(vm, location, env)
      @logger.info('Setting env from vmdk')
      env_json = JSON.dump(env)

      vmdk_path = "[#{location[:datastore]}] #{location[:vm]}/env.vmdk"
      @cpi.detach_independent_disk(vm, vmdk_path, location)

      @file_provider.upload_file(location[:datacenter],
                                 location[:datastore],
                                 "#{location[:vm]}/env.json", env_json)

      local_vmdk_file_dir = generate_vmdk_iso(env_json)
      begin
        convert_iso_to_vmdk(local_vmdk_file_dir)
        convert_vmdk_to_esx_type(local_vmdk_file_dir)

        upload_vmdk_file(location, local_vmdk_file_dir)
      ensure
        FileUtils.remove_entry_secure local_vmdk_file_dir
      end

      @cpi.attach_independent_disk(vm, vmdk_path, location, 3)
    end

  end
end
