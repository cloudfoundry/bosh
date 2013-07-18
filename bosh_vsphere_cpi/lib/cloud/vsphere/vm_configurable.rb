module VSphereCloud
  module VmConfigurable
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
        portgroup_properties = @client.get_properties(network, Vim::Dvs::DistributedVirtualPortgroup,
                                                     ["config.key", "config.distributedVirtualSwitch"],
                                                     ensure_all: true)

        switch = portgroup_properties["config.distributedVirtualSwitch"]
        switch_uuid = @client.get_property(switch, Vim::DistributedVirtualSwitch, "uuid", ensure_all: true)

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
  end
end
