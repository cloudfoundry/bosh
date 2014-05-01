module VSphereCloud
  class AgentEnv
    include VimSdk
    include RetryBlock

    def initialize(client, file_provider)
      @client = client
      @file_provider = file_provider
    end

    def get_current_env(location)
      contents = @file_provider.fetch_file(location[:datacenter], location[:datastore], "#{location[:vm]}/env.json")
      contents ? JSON.load(contents) : nil
    end

    def set_env(vm, location, env)
      env_json = JSON.dump(env)

      connect_cdrom(vm, false)
      @file_provider.upload_file(location[:datacenter], location[:datastore], "#{location[:vm]}/env.json", env_json)
      @file_provider.upload_file(location[:datacenter], location[:datastore], "#{location[:vm]}/env.iso", generate_env_iso(env_json))
      connect_cdrom(vm, true)
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

    def genisoimage
      @genisoimage ||= which(%w{genisoimage mkisofs})
    end

    def create_edit_device_spec(device)
      device_config_spec = Vim::Vm::Device::VirtualDeviceSpec.new
      device_config_spec.device = device
      device_config_spec.operation = Vim::Vm::Device::VirtualDeviceSpec::Operation::EDIT
      device_config_spec
    end
  end
end
