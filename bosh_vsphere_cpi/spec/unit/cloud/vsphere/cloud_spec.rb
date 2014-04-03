require 'yaml'
require 'spec_helper'

module VSphereCloud
  describe Cloud do
    let(:config) do
      settings = <<-INFO
agent:
  ntp:
   - ntp01.las01.emcatmos.com
vcenters:
  - host: 10.146.19.1
    user: r
    password: v
    datacenters:
      - name: datacenter1
        vm_folder: Manage VMs
        template_folder: BOSH_Templates
        disk_path: BOSH_Disks
        datastore_pattern: .*
        persistent_datastore_pattern: .*
        allow_mixed_datastores: true
        clusters:
          - cluster1
      INFO

      YAML.load(settings)
    end
    let(:cloud_config) { instance_double('VSphereCloud::Config', logger: logger, rest_client:nil ) }
    let(:logger) { instance_double('Logger', info: nil, debug: nil) }
    let(:client) { double('fake client') }

    shared_context 'base' do
      let(:vm) { double('vm', name: 'vm1') }
      let(:location) do
        {
          datacenter: 'datacenter1',
          datastore: 'datastore1',
          vm: 'vm1'
        }
      end
      let(:host_info) do
        {
          'cluster' => 'cluster1',
          'datastores' => ['datastore1', 'datastore2']
        }
      end
      let(:datastore) { double('datastore1', name: 'datastore1') }
      let(:cluster) { double('cluster1') }
      let(:networks) do
        {
          'default' => {
            'ip' => '10.146.17.174',
            'netmask' => '255.255.255.128',
            'cloud_properties' => {
              'name' => 'VM Network'
            },
            'default' => ['dns', 'gateway'],
            'dns' => ['10.146.17.140', '10.146.17.124'],
            'gateway' => '10.146.17.253'
          }
        }
      end
      let(:snapshot) { double('vm snapshot', current_snapshot: double('snapshot')) }
      let(:vm_properties) do
        {
          obj: double('vm1'),
          'config.hardware.device' =>
            [
              VimSdk::Vim::Vm::Device::VirtualIDEController.new,
              VimSdk::Vim::Vm::Device::VirtualPS2Controller.new,
              VimSdk::Vim::Vm::Device::VirtualPCIController.new,
              VimSdk::Vim::Vm::Device::VirtualSIOController.new,
              VimSdk::Vim::Vm::Device::VirtualKeyboard.new,
              VimSdk::Vim::Vm::Device::VirtualDisk.new
            ],
          'snapshot' => snapshot
        }
      end
      let(:vm_env) do
        {
          "vm" => {
            "name" => "vm-9536a37b-0bc4-4847-9cdc-ca3f33d50bd6",
            "id" => "vm-483"
          },
          "agent_id" => "73ca28f2-ae87-46ca-ad23-84a17eb11d11",
          "networks" => {
            "default" => {
              "ip" => "192.168.1.17",
              "netmask" => "255.255.255.128",
              "cloud_properties" => {
                "name" => "VM Network Private"},
              "default" => ["dns", "gateway"],
              "dns" => ["192.168.1.11", "10.146.17.124"],
              "gateway" => "192.168.1.1",
              "dns_record_name" => "0.cloud-controller-fa872c2249cf1acc9762.default.cf-9c670da16245d99a8384.microbosh",
              "mac"=>"00:50:56:a6:1d:72"
            }
          },
          "disks" => {
            "system" => 0,
            "ephemeral" => 1,
            "persistent" => {}
          },
          "ntp" => [],
          "blobstore" => {
            "provider" => "dav",
            "options" => {
              "endpoint" => "http://192.168.1.11:25250",
              "user"=>"agent",
              "password"=>"agent"
            }
          },
          "mbus" => "nats://nats:nats@192.168.1.11:4222",
          "env" => {
            "bosh" => {
              "password" => "pswd"
            }
          }
        }
      end
      let(:env_json){ JSON.dump(vm_env) }
      let(:agent_id) { 'agent_id' }
      let(:catalog_vapp_id) { 'catalog_vapp_id' }
      let(:vm_cid) { 'vm_cid' }
      let(:disk_cid) { 'disk_cid' }
      let(:resource_pool) do
        { 'ram' => 1024, 'cpu' => 2, 'disk' => 4096 }
      end
      let(:stemcell_vm) { double('stemcell_vm') }
      let(:disk) do
        disk = double('disk')
        disk.stub(:datacenter) { 'datacenter1' }
        disk.stub(:datastore) { 'datastore1' }
        disk.stub(:uuid) { 'uuid' }
        disk.stub(:path)
        disk.stub(:size) { 3 }
        disk.stub(:datacenter=)
        disk.stub(:datastore=)
        disk.stub(:path=)
        disk.stub(:save)
        disk
      end
      let(:disks) { double('disks') }
      let(:cluster1) do
        cluster1 = double('cluster1', mob: cluster)
        cluster1.stub_chain(:datacenter, :mob) { double('datacenter1') }
        cluster1.stub_chain(:datacenter, :name) { 'datacenter1' }
        cluster1.stub_chain(:datacenter, :vm_folder, :mob) { 'vm folder' }
        cluster1.stub_chain(:resource_pool, :mob) { 'resource pool' }
        cluster1
      end

      let(:datacenter) { double('datacenter1') }
      let(:datastore1) { double('datastore1', mob: datastore, name: 'datastore1') }
      let(:replicated_stemcell_vm) { double('replicated_stemcell_vm') }
      let(:attached_disk_config) { double('attached_disk_config') }
      let(:network_mob) { double('network_mob') }
      let(:nic_config) { double('nic_config') }
      let(:virtual_disk) do
        vdisk_controller_key = double('virtual disk controller key')
        VimSdk::Vim::Vm::Device::VirtualDisk.new(controller_key: vdisk_controller_key)
      end
      let(:pci_controller) do
        pci_controller_key = double('virtual pci controller key')
        VimSdk::Vim::Vm::Device::VirtualPCIController.new(key: pci_controller_key)
      end
    end

    subject(:vsphere_cloud) { Cloud.new(config) }

    before do
      allow(Config).to receive(:build).with(config).and_return(cloud_config)
      allow(cloud_config).to receive(:client).and_return(client)
      Cloud.any_instance.stub(:at_exit)
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
        PathFinder.stub(:new).and_return(path_finder)
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
            PathFinder.stub(:new).and_return(path_finder)
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
      let(:resources) { double('fake resources', datacenters: { key: datacenter }) }

      let(:datacenter) { double('fake datacenter', name: 'fake datacenter', vm_folder: vm_folder) }
      let(:vm_folder) { double('fake vm folder', name: 'fake vm folder name', mob: vm_folder_mob) }
      let(:vm_folder_mob) { double('fake folder mob', child_entity: [subfolder]) }
      let(:subfolder) { double('fake subfolder', child_entity: vms) }
      let(:vms) { ['fake vm 1', 'fake vm 2'] }

      before { Resources.stub(:new).and_return(resources) }

      it 'returns all vms in vm_folder of datacenter' do
        expect(vsphere_cloud.get_vms).to eq(['fake vm 1', 'fake vm 2'])
      end

      context 'when multiple datacenters exist in config' do
        let(:resources) { double('fake resources', datacenters: { key1: datacenter, key2: datacenter2 }) }

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

    describe '#attach_independent_disk' do
      include_context 'base'

      it 'attaches independent disk successfully' do
        attached_disk_config = double('attached_disk_config')
        datastore1 = double('datastore1')
        datastore1.stub(:mob) { datastore }

        subject
          .should_receive(:get_vm_host_info)
          .with(vm)
          .and_return host_info
        subject
          .should_receive(:find_persistent_datastore)
          .with(location[:datacenter],
                host_info,
                3)
          .and_return datastore1
        subject
          .client
          .should_receive(:get_properties)
          .with(vm,
                VimSdk::Vim::VirtualMachine,
                'config.hardware.device',
                ensure_all: true)
          .and_return vm_properties
        subject
          .should_receive(:create_disk_config_spec)
          .with(datastore,
                'vmdk_path',
                anything,
                3,
                create: false,
                independent: true)
          .and_return attached_disk_config
        subject
          .should_receive(:fix_device_unit_numbers)
          .with(anything, [attached_disk_config])
        subject
          .client
          .should_receive(:reconfig_vm)
          .with(vm, anything)

        expect do
          subject.send(:attach_independent_disk, vm, "vmdk_path", location, 3)
        end.to_not raise_error
      end

      context 'datastore does not exist' do
        it 'raises an exception' do
          attached_disk_config = double('attached_disk_config')
          subject
            .should_receive(:get_vm_host_info)
            .with(vm)
            .and_return host_info
          subject
            .should_receive('find_persistent_datastore')
            .with(location[:datacenter],
                  host_info,
                  3)
            .and_return nil
          subject
            .client
            .should_not_receive(:reconfig_vm)

          expect do
            subject.send(:attach_independent_disk, vm, "vmdk_path", location, 3)
          end.to raise_error "Unable to find datastore datastore1!"
        end
      end

      context 'error occurred when reconfiguring vm' do
        it 'raises the exception' do
          attached_disk_config = double('attached_disk_config')
          datastore1 = double('datastore1')
          datastore1.stub(:mob) { datastore }
          error_msg = "400 Bad Request"

          subject
            .should_receive(:get_vm_host_info)
            .with(vm)
            .and_return host_info
          subject
            .should_receive('find_persistent_datastore')
            .with(location[:datacenter],
                  host_info,
                  3)
            .and_return datastore1
          subject
            .client
            .should_receive(:get_properties)
            .with(vm,
                  VimSdk::Vim::VirtualMachine,
                  'config.hardware.device',
                  ensure_all: true)
            .and_return vm_properties
          subject
            .should_receive(:create_disk_config_spec)
            .with(datastore,
                  'vmdk_path',
                  anything,
                  3,
                  create: false,
                  independent: true)
            .and_return attached_disk_config
          subject
            .should_receive(:fix_device_unit_numbers)
            .with(anything, [attached_disk_config])
          subject
            .client
            .should_receive(:reconfig_vm)
            .with(vm, anything)
            .and_raise error_msg

          expect do
            subject.send(:attach_independent_disk, vm, "vmdk_path", location, 3)
          end.to raise_error error_msg
        end
      end
    end

    describe '#detach_independent_disk' do
      include_context 'base'

      it 'detaches independent disk successfully' do
        independent_disk = double('independent_disk')
        independent_disk
          .stub_chain(:backing, :uuid) { 1234 }
        subject
          .should_receive(:get_independent_disk_in_vm)
          .twice
          .with(vm, "vmdk_path")
          .and_return(independent_disk, nil)
        subject
          .client
          .should_receive(:reconfig_vm)
          .with(vm, anything)

        expect do
          subject.send(:detach_independent_disk, vm, "vmdk_path", location)
        end.to_not raise_error
      end

      context 'independent disk is not attached to vm' do
        it 'does not try to detach disk' do
          subject
            .should_receive(:get_independent_disk_in_vm)
            .with(vm, "vmdk_path")
            .and_return nil

          subject
            .client
            .should_not_receive(:reconfig_vm)

          expect do
            subject.send(:detach_independent_disk, vm, "vmdk_path", location)
          end.to_not raise_error
        end
      end

      context 'fail to detach disk' do
        it 'raises an exception' do
          independent_disk = double('independent_disk')
          independent_disk
            .stub_chain(:backing, :uuid) { 1234 }
          subject
            .should_receive(:get_independent_disk_in_vm)
            .exactly(6)
            .with(vm, "vmdk_path")
            .and_return(independent_disk)
          subject
            .client
            .should_receive(:reconfig_vm)
            .with(vm, anything)

          expect do
            subject.send(:detach_independent_disk, vm, "vmdk_path", location)
          end.to raise_error "Failed to detach disk: vmdk_path from vm: vm1"
        end
      end
    end

    describe '#set_vmdk_content' do
      include_context 'base'
      it 'sets content of vmdk successfully' do
        subject
          .should_receive(:detach_independent_disk)
          .ordered
          .with(vm, "[datastore1] vm1/env.vmdk", location)
        subject
          .should_receive(:upload_file)
          .ordered
          .with("datacenter1", "datastore1", "vm1/env.json", anything)
        subject
          .should_receive(:generate_vmdk)
          .ordered
          .and_return "local_vmdk_file_dir"
        subject
          .should_receive(:upload_vmdk_file)
          .ordered
          .with(location, "local_vmdk_file_dir")
        subject
          .should_receive(:attach_independent_disk)
          .ordered
          .with(vm, "[datastore1] vm1/env.vmdk", location, 3)
        FileUtils
          .should_receive(:remove_entry_secure)
          .with "local_vmdk_file_dir"

        expect do
          subject.send(:set_vmdk_content, vm, location, vm_env)
        end.to_not raise_error
      end
    end

    describe '#update_settings_json' do
      it 'updates json information' do
        content = 'VM_ENVIRONMENT_SETTINGS_BEGIN{"vm"}VM_ENVIRONMENT_SETTINGS_END'
        subject.send(:update_settings_json, content, settings_json)
        content.bytesize.should eql settings_json_with_spaces.bytesize
        content.should eql settings_json_with_spaces
      end

      context 'VM_ENVIRONMENT_SETTINGS_BEGIN string is missing' do
        it 'raises an exception' do
          content = settings_json_with_spaces
          expect do
            subject
              .send(:update_settings_json, content[29..-1], settings_json)
          end.to raise_exception 'Unable to find string VM_ENVIRONMENT_SETTINGS_BEGIN in settings file'
        end
      end

      context 'VM_ENVIRONMENT_SETTINGS_END string is missing' do
        it 'raises an exception' do
          content = settings_json_with_spaces
          expect do
            subject
              .send(:update_settings_json, content[0..-27], settings_json)
          end.to raise_exception 'Unable to find string VM_ENVIRONMENT_SETTINGS_END in settings file'
        end
      end

      context 'settings_json exceeds 1MB' do
        it 'raises an exception' do
          content = 'VM_ENVIRONMENT_SETTINGS_BEGIN{"vm"}VM_ENVIRONMENT_SETTINGS_END'
          settings_json = ' ' * 1025 * 1024
          expect do
            subject.send(:update_settings_json, content, settings_json)
          end.to raise_exception 'settings_json exceeds 1MB'
        end
      end

      private

      def settings_json
        %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},"disks":{"ephemeral":1,"persistent":{"250":2},"system":0},"mbus":"nats://user:pass@11.0.0.11:4222","networks":{"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70","ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"provider":"simple","options":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
      end

      def settings_json_with_spaces
        space_size = 1024 * 1024 - settings_json.bytesize
        "VM_ENVIRONMENT_SETTINGS_BEGIN#{settings_json}#{' ' * space_size}VM_ENVIRONMENT_SETTINGS_END"
      end
    end

    describe '#generate_vmdk' do

      after do
        `rm -rf #@local_vmdk_file_dir` unless @local_vmdk_file_dir.nil?
      end

      it 'generates vmdk files successfully' do
        vmdk_template = File.expand_path('../../../../../assets', __FILE__)

        @local_vmdk_file_dir = subject.send(:generate_vmdk, settings_json)
        exists = File.exists? File.join(@local_vmdk_file_dir, 'env.vmdk')
        exists.should == true
        exists = File.exists? File.join(@local_vmdk_file_dir, 'env-flat.vmdk')
        exists.should == true
      end

      private

      def settings_json
        %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},"disks":{"ephemeral":1,"persistent":{"250":2},"system":0},"mbus":"nats://user:pass@11.0.0.11:4222","networks":{"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70","ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"provider":"simple","options":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
      end
    end

    describe '#create_vm' do
      let(:resources) { double('resources') }
      before { allow(Resources).to receive(:new).and_return(resources) }
      it 'sets the thread name to create_vm followed by the agent id'

      describe 'delegating to the VmCreator class to create the VM' do
        let(:creator_builder) { instance_double('VSphereCloud::VmCreatorBuilder') }
        before do
          builder_class = class_double('VSphereCloud::VmCreatorBuilder').as_stubbed_const
          allow(builder_class).to receive(:new).with(no_args).and_return(creator_builder)
          allow(cloud_properties).to receive(:fetch).with('datacenters', []).and_return([])
        end
        let(:creator_instance) { instance_double('VSphereCloud::VmCreator') }

        let(:networks) { double('networks hash') }
        let(:cloud_properties) { double('cloud properties hash') }
        let(:stemcell_cid) { double('stemcell cid string') }
        let(:agent_id) { double('agent id string') }

        context 'using a placer' do
          let(:clusters) {
            [
              { "BOSH_CL" => {}, },
              { "BOSH_CL2" => {} }
            ]
          }

          let(:datacenters) {
            [{
              "name" => "BOSH_DC",
              "clusters" => clusters,
            }]
          }

          let(:placer) { double('placer') }
          let(:cluster) { double('cluster') }
          let(:datacenter) { double('datacenter') }

          before {
            allow(Resources::Datacenter).to receive(:new).with(cloud_config).and_return(datacenter)
            allow(cloud_properties).to receive(:fetch).with('datacenters', []).and_return(datacenters)
            allow(cloud_config).to receive(:datacenter_name).with(no_args).and_return(datacenters.first['name'])
            allow(datacenter).to receive(:clusters).with(no_args).and_return({'BOSH_CL' => cluster})

            placer_class = class_double('VSphereCloud::FixedClusterPlacer').as_stubbed_const
            allow(placer_class).to receive(:new).with(cluster).and_return(placer)
          }

          it 'passes disk locality and environment as nils' do
            vm = double('created vm')
            expect(creator_instance).to receive(:create).with(
                                          agent_id,
                                          stemcell_cid,
                                          networks,
                                          nil,
                                          nil,
                                        ).and_return(vm)
            expect(creator_builder).to receive(:build).with(
                                         placer, cloud_properties, client, logger, vsphere_cloud,
                                       ).and_return(creator_instance)

            expect(
              vsphere_cloud.create_vm(
                agent_id, stemcell_cid, cloud_properties, networks,
              )
            ).to eq(vm)
          end
        end

        context 'when both disk locality and environment are omitted' do
          it 'passes disk locality and environment as nils' do
            vm = double('created vm')
            expect(creator_instance).to receive(:create).with(
              agent_id,
              stemcell_cid,
              networks,
              nil,
              nil,
            ).and_return(vm)
            expect(creator_builder).to receive(:build).with(
              resources, cloud_properties, client, logger, vsphere_cloud,
            ).and_return(creator_instance)

            expect(
              vsphere_cloud.create_vm(
                agent_id, stemcell_cid, cloud_properties, networks,
              )
            ).to eq(vm)
          end
        end

        context 'when only environment is omitted' do
          it 'passes environment as nil' do
            vm = double('created vm')
            disk_cids = double('disk cids array')
            expect(creator_instance).to receive(:create).with(
              agent_id,
              stemcell_cid,
              networks,
              disk_cids,
              nil,
            ).and_return(vm)
            expect(creator_builder).to receive(:build).with(
              resources, cloud_properties, client, logger, vsphere_cloud,
            ).and_return(creator_instance)

            expect(
              vsphere_cloud.create_vm(
                agent_id, stemcell_cid, cloud_properties, networks, disk_cids,
              )
            ).to eq(vm)
          end
        end

        context 'when the caller passes all 6 arguments' do
          it 'passes all 6 arguments' do
            vm = double('created vm')
            disk_cids = double('disk cids array')
            environment = double('environment hash')
            expect(creator_instance).to receive(:create).with(
              agent_id,
              stemcell_cid,
              networks,
              disk_cids,
              environment,
            ).and_return(vm)
            expect(creator_builder).to receive(:build).with(
              resources, cloud_properties, client, logger, vsphere_cloud,
            ).and_return(creator_instance)

            expect(
              vsphere_cloud.create_vm(
                agent_id, stemcell_cid, cloud_properties, networks, disk_cids, environment
              )
            ).to eq(vm)
          end
        end
      end
    end

    describe '#attach_disk' do
      include_context 'base'

      context 'SRM is not enabled' do
        it 'attaches a disk to vm' do
          VSphereCloud::Models::Disk
            .should_receive(:first)
            .with(uuid: disk_cid)
            .and_return disk
          subject
            .should_receive(:get_vm_by_cid)
            .with(vm_cid)
            .and_return vm
          subject
            .client
            .should_receive(:find_parent)
            .with(vm, VimSdk::Vim::Datacenter)
            .and_return datacenter
          subject
            .client
            .should_receive(:get_property)
            .with(datacenter, VimSdk::Vim::Datacenter, 'name')
            .and_return 'datacenter1'
          subject
            .client
            .should_receive(:get_properties)
            .with(vm,
                  VimSdk::Vim::VirtualMachine,
                  'config.hardware.device',
                  ensure_all: true)
            .and_return vm_properties
          subject
            .should_receive(:get_vm_host_info)
            .and_return host_info
          subject
            .should_receive(:find_persistent_datastore)
            .with('datacenter1', host_info, 3)
            .and_return datastore1
          subject
            .instance_variable_get(:@resources)
            .stub_chain('datacenters.[].disk_path')
            .and_return 'datacenter_disk_path'
          subject
            .should_receive(:create_disk_config_spec)
            .with(datastore,
                  '.vmdk',
                  anything,
                  3,
                  create: true,
                  independent: true)
            .and_return attached_disk_config
          subject
            .should_receive(:fix_device_unit_numbers)
            .with(anything, [attached_disk_config])
          subject
            .should_receive(:get_vm_location)
            .with(vm, datacenter: 'datacenter1')
            .and_return location
          subject
            .should_receive(:get_current_agent_env)
            .with(location)
            .and_return vm_env
          attached_disk_config
            .stub_chain('device.unit_number') { 'uuid_num' }
          subject
            .instance_variable_get(:@config)
            .should_receive(:datacenter_srm)
            .and_return false
          subject
            .should_receive(:set_cdrom_content)
            .with(vm, location, vm_env)
          subject
            .client
            .should_receive(:reconfig_vm)
            .with(vm, anything)

          expect do
            subject.attach_disk(vm_cid, disk_cid)
          end.to_not raise_error
        end
      end

      context 'SRM is enabled' do
        it 'attaches a disk to vm' do
          VSphereCloud::Models::Disk
            .should_receive(:first)
            .with(uuid: disk_cid)
            .and_return disk
          subject
            .should_receive(:get_vm_by_cid)
            .with(vm_cid)
            .and_return vm
          subject
            .client
            .should_receive(:find_parent)
            .with(vm, VimSdk::Vim::Datacenter)
            .and_return datacenter
          subject
            .client
            .should_receive(:get_property)
            .with(datacenter, VimSdk::Vim::Datacenter, 'name')
            .and_return 'datacenter1'
          subject
            .client
            .should_receive(:get_properties)
            .with(vm,
                  VimSdk::Vim::VirtualMachine,
                  'config.hardware.device',
                  ensure_all: true)
            .and_return vm_properties
          subject
            .should_receive(:get_vm_host_info)
            .and_return host_info
          subject
            .should_receive(:find_persistent_datastore)
            .with('datacenter1', host_info, 3)
            .and_return datastore1
          subject
            .instance_variable_get(:@resources)
            .stub_chain('datacenters.[].disk_path')
            .and_return 'datacenter_disk_path'
          subject
            .should_receive(:create_disk_config_spec)
            .with(datastore,
                  '.vmdk',
                  anything,
                  3,
                  create: true,
                  independent: true)
            .and_return attached_disk_config
          subject
            .should_receive(:fix_device_unit_numbers)
            .with(anything, [attached_disk_config])
          subject
            .should_receive(:get_vm_location)
            .with(vm, datacenter: 'datacenter1')
            .and_return location
          subject
            .should_receive(:get_current_agent_env)
            .with(location)
            .and_return vm_env
          attached_disk_config
            .stub_chain('device.unit_number') { 'uuid_num' }
          subject
            .instance_variable_get(:@config)
            .should_receive(:datacenter_srm)
            .and_return true
          subject
            .should_receive(:set_vmdk_content)
            .with(vm, location, vm_env)
          subject
            .client
            .should_receive(:reconfig_vm)
            .with(vm, anything)

          expect do
            subject.attach_disk(vm_cid, disk_cid)
          end.to_not raise_error
        end
      end
    end

    describe '#detach_disk' do
      include_context 'base'
      context 'SRM is not enabled' do
        it 'detaches the disk from vm' do
          virtual_disk.stub_chain('backing.file_name') { '.vmdk' }
          VSphereCloud::Models::Disk
            .should_receive(:first)
            .with(uuid: disk_cid)
            .and_return disk
          subject
            .should_receive(:get_vm_by_cid)
            .with(vm_cid)
            .and_return vm
          subject
            .client
            .should_receive(:get_property)
            .with(vm,
                  VimSdk::Vim::VirtualMachine,
                  'config.hardware.device',
                  ensure_all: true)
            .and_return([virtual_disk], [])
          subject
            .should_receive(:create_delete_device_spec)
            .with(virtual_disk)
          subject
            .should_receive(:get_vm_location)
            .with(vm)
            .and_return location
          subject
            .should_receive(:get_current_agent_env)
            .with(location)
            .and_return vm_env
          subject
            .instance_variable_get(:@config)
            .should_receive(:datacenter_srm)
            .and_return false
          subject
            .should_receive(:set_cdrom_content)
            .with(vm, location, vm_env)
          subject
            .client
            .should_receive(:reconfig_vm)
            .with(vm, anything)

          expect do
            subject.detach_disk(vm_cid, disk_cid)
          end.to_not raise_error
        end
      end

      context 'SRM is enabled' do
        it 'detaches the disk from vm' do
          virtual_disk.stub_chain('backing.file_name') { '.vmdk' }
          VSphereCloud::Models::Disk
            .should_receive(:first)
            .with(uuid: disk_cid)
            .and_return disk
          subject
            .should_receive(:get_vm_by_cid)
            .with(vm_cid)
            .and_return vm
          subject
            .client
            .should_receive(:get_property)
            .with(vm,
                  VimSdk::Vim::VirtualMachine,
                  'config.hardware.device',
                  ensure_all: true)
            .and_return([virtual_disk], [])
          subject
            .should_receive(:create_delete_device_spec)
            .with(virtual_disk)
          subject
            .should_receive(:get_vm_location)
            .with(vm)
            .and_return location
          subject
            .should_receive(:get_current_agent_env)
            .with(location)
            .and_return vm_env
          subject
            .instance_variable_get(:@config)
            .should_receive(:datacenter_srm)
            .and_return true
          subject
            .should_receive(:set_vmdk_content)
            .with(vm, location, vm_env)
          subject
            .client
            .should_receive(:reconfig_vm)
            .with(vm, anything)

          expect do
            subject.detach_disk(vm_cid, disk_cid)
          end.to_not raise_error
        end
      end

      context 'detaching disk fails' do
        it 'raises an exception' do
          virtual_disk.stub_chain('backing.file_name') { '.vmdk' }
          VSphereCloud::Models::Disk
            .should_receive(:first)
            .with(uuid: disk_cid)
            .and_return disk
          subject
            .should_receive(:get_vm_by_cid)
            .with(vm_cid)
            .and_return vm
          subject
            .client
            .should_receive(:get_property)
            .exactly(6)
            .with(vm,
                  VimSdk::Vim::VirtualMachine,
                  'config.hardware.device',
                  ensure_all: true)
            .and_return([virtual_disk])
          subject
            .should_receive(:create_delete_device_spec)
            .with(virtual_disk)
          subject
            .should_receive(:get_vm_location)
            .with(vm)
            .and_return location
          subject
            .should_receive(:get_current_agent_env)
            .with(location)
            .and_return vm_env
          subject
            .should_receive(:set_agent_env)
            .with(vm, location, vm_env)
          subject
            .client
            .should_receive(:reconfig_vm)
            .with(vm, anything)

          expect do
            subject.detach_disk(vm_cid, disk_cid)
          end.to raise_exception "Failed to detach disk: disk_cid from vm: vm_cid"
        end
      end
    end

    describe '#configure_networks' do
      include_context 'base'

      context 'SRM is not enabled' do
        it 'configures the networks' do
          network_mob = double('network_mob')
          subject
            .should_receive(:get_vm_by_cid)
            .twice
            .with(vm_cid)
            .and_return vm
          subject
            .should_receive(:wait_until_off)
            .with(vm, 30)
          subject
            .client
            .should_receive(:get_property)
            .with(vm,
                  VimSdk::Vim::VirtualMachine,
                  'config.hardware.device',
                  ensure_all: true)
            .and_return(vm_properties['config.hardware.device'])
          subject
            .client
            .should_receive(:find_parent)
            .with(vm, VimSdk::Vim::Datacenter)
            .and_return datacenter
          subject
            .client
            .should_receive(:get_property)
            .with(datacenter,
                  VimSdk::Vim::Datacenter,
                  'name')
            .and_return 'datacenter1'
          subject
            .client
            .should_receive(:find_by_inventory_path)
            .with(['datacenter1', 'network', 'VM Network'])
            .and_return network_mob
          subject
            .should_receive(:create_nic_config_spec)
            .with('VM Network',
                  network_mob,
                  anything,
                  {})
          subject
            .should_receive(:fix_device_unit_numbers)
          subject
            .client
            .should_receive(:reconfig_vm)
            .with(vm, anything)
          subject
            .should_receive(:get_vm_location)
            .with(vm, datacenter: 'datacenter1')
            .and_return location
          subject
            .should_receive(:get_current_agent_env)
            .with(location)
            .and_return vm_env
          subject
            .client
            .should_receive(:get_property)
            .with(vm,
                  VimSdk::Vim::VirtualMachine,
                  'config.hardware.device',
                  ensure_all: true)
          subject
            .should_receive(:generate_network_env)
          subject
            .instance_variable_get(:@config)
            .should_receive(:datacenter_srm)
            .and_return false
          subject
            .should_receive(:set_cdrom_content)
            .with(vm, location, vm_env)
          subject
            .client
            .should_receive(:power_on_vm)
            .with(datacenter, vm)

          expect do
            subject.configure_networks(vm_cid, networks)
          end.to_not raise_error
        end
      end

      context 'SRM is enabled' do
        it 'configures the networks' do
          network_mob = double('network_mob')
          subject
            .should_receive(:get_vm_by_cid)
            .twice
            .with(vm_cid)
            .and_return vm
          subject
            .should_receive(:wait_until_off)
            .with(vm, 30)
          subject
            .client
            .should_receive(:get_property)
            .with(vm,
                  VimSdk::Vim::VirtualMachine,
                  'config.hardware.device',
                  ensure_all: true)
            .and_return(vm_properties['config.hardware.device'])
          subject
            .client
            .should_receive(:find_parent)
            .with(vm, VimSdk::Vim::Datacenter)
            .and_return datacenter
          subject
            .client
            .should_receive(:get_property)
            .with(datacenter,
                  VimSdk::Vim::Datacenter,
                  'name')
            .and_return 'datacenter1'
          subject
            .client
            .should_receive(:find_by_inventory_path)
            .with(['datacenter1', 'network', 'VM Network'])
            .and_return network_mob
          subject
            .should_receive(:create_nic_config_spec)
            .with('VM Network',
                  network_mob,
                  anything,
                  {})
          subject
            .should_receive(:fix_device_unit_numbers)
          subject
            .client
            .should_receive(:reconfig_vm)
            .with(vm, anything)
          subject
            .should_receive(:get_vm_location)
            .with(vm, datacenter: 'datacenter1')
            .and_return location
          subject
            .should_receive(:get_current_agent_env)
            .with(location)
            .and_return vm_env
          subject
            .client
            .should_receive(:get_property)
            .with(vm,
                  VimSdk::Vim::VirtualMachine,
                  'config.hardware.device',
                  ensure_all: true)
          subject
            .should_receive(:generate_network_env)
          subject
            .instance_variable_get(:@config)
            .should_receive(:datacenter_srm)
            .and_return true
          subject
            .should_receive(:set_vmdk_content)
            .with(vm, location, vm_env)
          subject
            .client
            .should_receive(:power_on_vm)
            .with(datacenter, vm)

          expect do
            subject.configure_networks(vm_cid, networks)
          end.to_not raise_error
        end
      end
    end
  end
end
