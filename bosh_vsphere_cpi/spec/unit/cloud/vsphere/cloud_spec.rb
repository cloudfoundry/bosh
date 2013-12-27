require 'spec_helper'

describe VSphereCloud::Cloud do
  let(:config) { { fake: 'config' } }
  let(:client) { double('fake client') }

  subject(:vsphere_cloud) { VSphereCloud::Cloud.new(config) }

  before do
    VSphereCloud::Config.should_receive(:configure).with(config)
    VSphereCloud::Config.stub(client: client)
    VSphereCloud::Cloud.any_instance.stub(:at_exit)
  end

  describe '#fix_device_unit_numbers' do
    let(:device_class) { Struct.new(:unit_number, :controller_key) }
    let(:device_change_class) { Struct.new(:device) }
    let(:dnil) { device_class.new(nil, 0) }

    def self.it_assigns_available_unit_numbers_for_devices_in_change_set
      it 'assigns available unit numbers for devices in change set' do
        vsphere_cloud.fix_device_unit_numbers(devices, device_changes)

        devices.each do |d|
          expect((0..15).to_a).to include(d.unit_number) if d.controller_key
        end

        device_changes.map(&:device).each do |d|
          expect((0..15).to_a).to include(d.unit_number) if d.controller_key
        end
      end
    end

    context 'when no devices' do
      let(:device_change) { device_change_class.new(dnil) }
      let(:devices) { [] }
      let(:device_changes) { [device_change] }
      it_assigns_available_unit_numbers_for_devices_in_change_set
    end

    context 'when a device has unit number 15 and a change has nil for same cont' do
      let(:d15) { device_class.new(15, 0) }
      let(:devices) { [d15] }
      let(:device_change) { device_change_class.new(dnil) }
      let(:device_changes) { [device_change] }
      it_assigns_available_unit_numbers_for_devices_in_change_set
    end

    context 'when all unit number slots in controller are full' do
      let(:devices) do
        (0..15).map { |x| device_class.new(x, 0) }
      end

      let(:device_change) { device_change_class.new(dnil) }
      let(:device_changes) { [device_change] }

      it 'raises error with the device inspected' do
        expect {
          vsphere_cloud.fix_device_unit_numbers(devices, device_changes)
        }.to raise_error(RuntimeError, /No available unit numbers for device: .*struct unit_number=nil, controller_key=0/)
      end
    end

    context 'when there are multiple controller_keys on the devices' do
      let(:devices) do
        [
          device_class.new(1, 0),
          device_class.new(1, 1),
          device_class.new(4, 0),
          device_class.new(5, 1),
          device_class.new(nil, 0),
          device_class.new(nil, 1),
          device_class.new(14, 0),
          device_class.new(15, 1),
          device_class.new(1, nil),
          device_class.new(4, nil),
          device_class.new(nil, 0),
          device_class.new(nil, nil),
        ]
      end

      let(:device_changes) do
        devices.values_at(2, 4, 5, 7, 8, 9, 10, 11).map do |device|
          device_change_class.new(device)
        end
      end

      it 'assigns available unit numbers for devices in change set' do
        vsphere_cloud.fix_device_unit_numbers(devices, device_changes)

        expect(devices[0].to_a).to eq [1, 0]
        expect(devices[1].to_a).to eq [1, 1]
        expect(devices[2].to_a).to eq [4, 0]
        expect(devices[3].to_a).to eq [5, 1]
        expect(devices[4].to_a).to eq [0, 0]
        expect(devices[5].to_a).to eq [0, 1]
        expect(devices[6].to_a).to eq [14, 0]
        expect(devices[7].to_a).to eq [15, 1]
        expect(devices[8].to_a).to eq [1, nil]
        expect(devices[9].to_a).to eq [4, nil]
        expect(devices[10].to_a).to eq [2, 0]
        expect(devices[11].to_a).to eq [nil, nil]
      end
    end
  end

  describe 'has_vm?' do
    let(:vm_id) { 'vm_id' }

    context 'the vm is found' do
      it 'returns true' do
        vsphere_cloud.should_receive(:get_vm_by_cid).with(vm_id)
        expect(vsphere_cloud.has_vm?(vm_id)).to be(true)
      end
    end

    context 'the vm is not found' do
      it 'returns false' do
        vsphere_cloud.should_receive(:get_vm_by_cid).with(vm_id).and_raise(Bosh::Clouds::VMNotFound)
        expect(vsphere_cloud.has_vm?(vm_id)).to be(false)
      end
    end
  end

  describe 'snapshot_disk' do
    it 'raises not implemented exception when called' do
      expect { vsphere_cloud.snapshot_disk('123') }.to raise_error(Bosh::Clouds::NotImplemented)
    end
  end

  describe '#replicate_stemcell' do
    let(:stemcell_vm) { double('fake local stemcell') }
    let(:stemcell_id) { 'fake_stemcell_id' }

    let(:datacenter) do
      datacenter = double('fake datacenter', name: 'fake_datacenter')
      datacenter.stub_chain(:template_folder, :name).and_return('fake_template_folder')
      datacenter
    end
    let(:cluster) { double('fake cluster', datacenter: datacenter) }
    let(:datastore) { double('fake datastore') }

    context 'when stemcell vm is not found at the expected location' do
      it 'raises an error' do
        client.stub(find_by_inventory_path: nil)

        expect {
          vsphere_cloud.replicate_stemcell(cluster, datastore, 'fake_stemcell_id')
        }.to raise_error(/Could not find stemcell/)
      end
    end

    context 'when stemcell vm resides on a different datastore' do
      before do
        datastore.stub_chain(:mob, :__mo_id__).and_return('fake_datastore_managed_object_id')
        client.stub(:find_by_inventory_path).with(
          [
            cluster.datacenter.name,
            'vm',
            cluster.datacenter.template_folder.name,
            stemcell_id,
          ]
        ).and_return(stemcell_vm)

        client.stub(:get_property).with(stemcell_vm, anything, 'datastore', anything).and_return('fake_stemcell_datastore')
      end

      it 'searches for stemcell on all cluster datastores' do
        client.should_receive(:find_by_inventory_path).with(
          [
            cluster.datacenter.name,
            'vm',
            cluster.datacenter.template_folder.name,
            "#{stemcell_id} %2f #{datastore.mob.__mo_id__}",
          ]
        ).and_return(double('fake stemcell vm'))

        vsphere_cloud.replicate_stemcell(cluster, datastore, stemcell_id)
      end

      context 'when the stemcell replica is not found in the datacenter' do
        let(:replicated_stemcell) { double('fake_replicated_stemcell') }
        let(:fake_task) { 'fake_task' }

        it 'replicates the stemcell' do
          client.stub(:find_by_inventory_path).with(
            [
              cluster.datacenter.name,
              'vm',
              cluster.datacenter.template_folder.name,
              "#{stemcell_id} %2f #{datastore.mob.__mo_id__}",
            ]
          )

          datacenter.stub_chain(:template_folder, :mob).and_return('fake_template_folder_mob')
          cluster.stub_chain(:resource_pool, :mob).and_return('fake_resource_pool_mob')
          stemcell_vm.stub(:clone).with(any_args).and_return(fake_task)
          client.stub(:wait_for_task).with(fake_task).and_return(replicated_stemcell)
          replicated_stemcell.stub(:create_snapshot).with(any_args).and_return(fake_task)

          vsphere_cloud.replicate_stemcell(cluster, datastore, stemcell_id).should eq(replicated_stemcell)
        end
      end
    end

    context 'when stemcell resides on the given datastore' do
      it 'returns the found replica' do
        client.stub(:find_by_inventory_path).with(any_args).and_return(stemcell_vm)
        client.stub(:get_property).with(any_args).and_return(datastore)
        datastore.stub(:mob).and_return(datastore)
        vsphere_cloud.replicate_stemcell(cluster, datastore, stemcell_id).should eq(stemcell_vm)
      end
    end
  end

  describe '#generate_network_env' do
    let(:device) { instance_double('VimSdk::Vim::Vm::Device::VirtualEthernetCard', backing: backing, mac_address: '00:00:00:00:00:00') }
    let(:devices) { [device] }
    let(:network1) {
      {
        'cloud_properties' => {
          'name' => 'fake_network1'
        }
      }
    }
    let(:networks) { { 'fake_network1' => network1 } }
    let(:dvs_index) { {} }
    let(:expected_output) { {
      'fake_network1' => {
        'cloud_properties' => {
          'name' => 'fake_network1'
        },
        'mac' => '00:00:00:00:00:00'
      }
    } }
    let(:path_finder) { instance_double('VSphereCloud::PathFinder') }

    before do
      device.stub(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualEthernetCard) { true }
      VSphereCloud::PathFinder.stub(:new).and_return(path_finder)
      path_finder.stub(:path).with(any_args).and_return('fake_network1')
    end

    context 'using a distributed switch' do
      let(:backing) { instance_double('VimSdk::Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo') }
      let(:dvs_index) { { 'fake_pgkey1' => 'fake_network1' } }

      it 'generates the network env' do
        backing.stub(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo) { true }
        backing.stub_chain(:port, :portgroup_key) { 'fake_pgkey1' }

        expect(vsphere_cloud.generate_network_env(devices, networks, dvs_index)).to eq(expected_output)
      end
    end

    context 'using a standard switch' do
      let(:backing) { double(network: 'fake_network1') }

      it 'generates the network env' do
        backing.stub(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo) { false }

        expect(vsphere_cloud.generate_network_env(devices, networks, dvs_index)).to eq(expected_output)
      end
    end

    context 'passing in device that is not a VirtualEthernetCard' do
      let(:devices) { [device, double()] }
      let(:backing) { double(network: 'fake_network1') }

      it 'ignores non VirtualEthernetCard devices' do
        backing.stub(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo) { false }

        expect(vsphere_cloud.generate_network_env(devices, networks, dvs_index)).to eq(expected_output)
      end
    end

    context 'when the network is in a folder' do

      context 'using a standard switch' do
        let(:path_finder) { instance_double('VSphereCloud::PathFinder') }
        let(:fake_network_object) { double() }
        let(:backing) { double(network: fake_network_object) }
        let(:network1) {
          {
            'cloud_properties' => {
              'name' => 'networks/fake_network1'
            }
          }
        }
        let(:networks) { { 'networks/fake_network1' => network1 } }
        let(:expected_output) { {
          'networks/fake_network1' => {
            'cloud_properties' => {
              'name' => 'networks/fake_network1'
            },
            'mac' => '00:00:00:00:00:00'
          }
        } }

        it 'generates the network env' do
          VSphereCloud::PathFinder.stub(:new).and_return(path_finder)
          path_finder.stub(:path).with(fake_network_object).and_return('networks/fake_network1')

          backing.stub(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo) { false }

          expect(vsphere_cloud.generate_network_env(devices, networks, dvs_index)).to eq(expected_output)
        end
      end

    end

  end

  describe '#create_nic_config_spec' do
    let(:dvs_index) { {} }

    context 'using a distributed switch' do
      let(:v_network_name) { 'fake_network1' }
      let(:network) { instance_double('VimSdk::Vim::Dvs::DistributedVirtualPortgroup', class: VimSdk::Vim::Dvs::DistributedVirtualPortgroup) }
      let(:dvs_index) { {} }
      let(:switch) { double() }
      let(:portgroup_properties) { { 'config.distributedVirtualSwitch' => switch, 'config.key' => 'fake_portgroup_key' } }

      before do
        client.stub(:get_properties).with(network, VimSdk::Vim::Dvs::DistributedVirtualPortgroup,
                                          ['config.key', 'config.distributedVirtualSwitch'],
                                          ensure_all: true).and_return(portgroup_properties)

        client.stub(:get_property).with(switch, VimSdk::Vim::DistributedVirtualSwitch,
                                        'uuid', ensure_all: true).and_return('fake_switch_uuid')
      end

      it 'sets correct port in device config spec' do
        device_config_spec = vsphere_cloud.create_nic_config_spec(v_network_name, network, 'fake_controller_key', dvs_index)

        port = device_config_spec.device.backing.port
        expect(port.switch_uuid).to eq('fake_switch_uuid')
        expect(port.portgroup_key).to eq('fake_portgroup_key')
      end

      it 'sets correct backing in device config spec' do
        device_config_spec = vsphere_cloud.create_nic_config_spec(v_network_name, network, 'fake_controller_key', dvs_index)

        backing = device_config_spec.device.backing
        expect(backing).to be_a(VimSdk::Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo)
      end

      it 'adds record to dvs_index for portgroup_key' do
        vsphere_cloud.create_nic_config_spec(v_network_name, network, 'fake_controller_key', dvs_index)

        expect(dvs_index['fake_portgroup_key']).to eq('fake_network1')
      end

      it 'sets correct device in device config spec' do
        device_config_spec = vsphere_cloud.create_nic_config_spec(v_network_name, network, 'fake_controller_key', dvs_index)

        device = device_config_spec.device
        expect(device.key).to eq(-1)
        expect(device.controller_key).to eq('fake_controller_key')
      end

      it 'sets correct operation in device config spec' do
        device_config_spec = vsphere_cloud.create_nic_config_spec(v_network_name, network, 'fake_controller_key', dvs_index)

        expect(device_config_spec.operation).to eq(VimSdk::Vim::Vm::Device::VirtualDeviceSpec::Operation::ADD)
      end
    end

    context 'using a standard switch' do
      let(:v_network_name) { 'fake_network1' }
      let(:network) { double(name: v_network_name) }
      let(:dvs_index) { {} }

      it 'sets correct backing in device config spec' do
        device_config_spec = vsphere_cloud.create_nic_config_spec(v_network_name, network, 'fake_controller_key', dvs_index)

        backing = device_config_spec.device.backing
        expect(backing).to be_a(VimSdk::Vim::Vm::Device::VirtualEthernetCard::NetworkBackingInfo)
        expect(backing.device_name).to eq(v_network_name)
      end

      it 'sets correct device in device config spec' do
        device_config_spec = vsphere_cloud.create_nic_config_spec(v_network_name, network, 'fake_controller_key', dvs_index)

        device = device_config_spec.device
        expect(device.key).to eq(-1)
        expect(device.controller_key).to eq('fake_controller_key')
      end

      it 'sets correct operation in device config spec' do
        device_config_spec = vsphere_cloud.create_nic_config_spec(v_network_name, network, 'fake_controller_key', dvs_index)

        expect(device_config_spec.operation).to eq(VimSdk::Vim::Vm::Device::VirtualDeviceSpec::Operation::ADD)
      end
    end
  end

  describe '#get_vms' do
    let(:resources) { double('fake resources', datacenters: {key: datacenter}) }

    let(:datacenter) { double('fake datacenter', name: 'fake datacenter', vm_folder: vm_folder) }
    let(:vm_folder) { double('fake vm folder', name: 'fake vm folder name', mob: vm_folder_mob) }
    let(:vm_folder_mob) { double('fake folder mob', child_entity: [subfolder]) }
    let(:subfolder) { double('fake subfolder', child_entity: vms) }
    let(:vms) { ['fake vm 1', 'fake vm 2'] }

    before { VSphereCloud::Resources.stub(:new).and_return(resources) }

    it 'returns all vms in vm_folder of datacenter' do
      expect(vsphere_cloud.get_vms).to eq(['fake vm 1', 'fake vm 2'])
    end

    context 'when multiple datacenters exist in config' do
      let(:resources) { double('fake resources', datacenters: {key1: datacenter, key2: datacenter2}) }

      let(:datacenter2) { double('another fake datacenter', name: 'fake datacenter 2', vm_folder: vm_folder2) }
      let(:vm_folder2) { double('another fake vm folder', name: 'another fake vm folder name', mob: vm_folder2_mob) }
      let(:vm_folder2_mob) { double('another fake folder mob', child_entity: [subfolder2]) }
      let(:subfolder2) { double('another fake subfolder', child_entity: vms2) }
      let(:vms2) { ['fake vm 3', 'fake vm 4'] }

      it 'returns all vms in vm_folder of all datacenters' do
        expect(vsphere_cloud.get_vms).to eq(['fake vm 1', 'fake vm 2', 'fake vm 3', 'fake vm 4'])
      end
    end
  end
end
