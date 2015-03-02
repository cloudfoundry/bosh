module VSphereCloud
  class DiskConfig
    def initialize(datastore_name, filename, controller_key, size_in_mb)
      @datastore_name = datastore_name
      @filename = filename
      @controller_key = controller_key
      @size_in_mb = size_in_mb
    end

    def spec(options)
      backing_info = VimSdk::Vim::Vm::Device::VirtualDisk::FlatVer2BackingInfo.new
      backing_info.datastore = @datastore_name
      if options[:independent]
        backing_info.disk_mode = VimSdk::Vim::Vm::Device::VirtualDiskOption::DiskMode::INDEPENDENT_PERSISTENT
      else
        backing_info.disk_mode = VimSdk::Vim::Vm::Device::VirtualDiskOption::DiskMode::PERSISTENT
      end
      backing_info.file_name = @filename

      virtual_disk = VimSdk::Vim::Vm::Device::VirtualDisk.new
      virtual_disk.key = -1
      virtual_disk.controller_key = @controller_key
      virtual_disk.backing = backing_info
      virtual_disk.capacity_in_kb = @size_in_mb * 1024

      device_config_spec = VimSdk::Vim::Vm::Device::VirtualDeviceSpec.new
      device_config_spec.device = virtual_disk
      device_config_spec.operation = VimSdk::Vim::Vm::Device::VirtualDeviceSpec::Operation::ADD
      if options[:create]
        device_config_spec.file_operation = VimSdk::Vim::Vm::Device::VirtualDeviceSpec::FileOperation::CREATE
      end
      device_config_spec
    end
  end
end
