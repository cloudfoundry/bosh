require 'spec_helper'

module VSphereCloud
  describe Cloud do
    let(:config) { { fake: 'config' } }
    let(:cloud_config) { instance_double('VSphereCloud::Config', logger: logger, rest_client:nil ).as_null_object }
    let(:logger) { instance_double('Logger', info: nil, debug: nil) }
    let(:client) { double('fake client') }

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

      let(:datacenter) { double('fake datacenter', name: 'fake datacenter',
                                                   vm_folder: vm_folder,
                                                   template_folder: template_folder) }
      let(:vm_folder) { double('fake vm folder', name: 'fake vm folder name', mob: vm_folder_mob) }
      let(:vm_folder_mob) { double('fake folder mob', child_entity: [subfolder]) }
      let(:subfolder) { double('fake subfolder', child_entity: vms) }
      let(:vms) { ['fake vm 1', 'fake vm 2'] }

      let(:template_folder) { double('fake template template folder', name: 'fake template folder name',
                                                                      mob: template_folder_mob)}
      let(:template_folder_mob) { double('fake template folder mob', child_entity: [template_subfolder]) }
      let(:template_subfolder) { double('fake template subfolder', child_entity: stemcells) }
      let(:stemcells) { ['fake stemcell 1', 'fake stemcell 2'] }

      before { Resources.stub(:new).and_return(resources) }

      it 'returns all vms in vm_folder of datacenter and all stemcells in template_folder' do
        expect(vsphere_cloud.get_vms).to eq(['fake vm 1', 'fake vm 2', 'fake stemcell 1', 'fake stemcell 2'])
      end

      context 'when multiple datacenters exist in config' do
        let(:resources) { double('fake resources', datacenters: { key1: datacenter, key2: datacenter2 }) }

        let(:datacenter2) { double('another fake datacenter', name: 'fake datacenter 2',
                                                              vm_folder: vm_folder2,
                                                              template_folder: template_folder2) }
        let(:vm_folder2) { double('another fake vm folder', name: 'another fake vm folder name', mob: vm_folder2_mob) }
        let(:vm_folder2_mob) { double('another fake folder mob', child_entity: [subfolder2]) }
        let(:subfolder2) { double('another fake subfolder', child_entity: vms2) }
        let(:vms2) { ['fake vm 3', 'fake vm 4'] }

        let(:template_folder2) { double('another fake template folder', name: 'another fake template folder name',
                                                                        mob: template_folder2_mob) }
        let(:template_folder2_mob) { double('another fake template folder mob', child_entity: [template_subfolder2]) }
        let(:template_subfolder2) { double('another fake subfolder', child_entity: stemcells2) }
        let(:stemcells2) { ['fake stemcell 3', 'fake stemcell 4'] }

        it 'returns all vms in vm_folder and all stemcells in template_folder of all datacenters' do
          expect(vsphere_cloud.get_vms).to eq(['fake vm 1', 'fake vm 2', 'fake stemcell 1', 'fake stemcell 2',
                                               'fake vm 3', 'fake vm 4', 'fake stemcell 3', 'fake stemcell 4'])
        end
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

        let(:file_provider) { instance_double('VSphereCloud::FileProvider') }
        before { allow(VSphereCloud::FileProvider).to receive(:new).and_return(file_provider) }

        let(:agent_env) { instance_double('VSphereCloud::AgentEnv') }
        before { allow(VSphereCloud::AgentEnv).to receive(:new).and_return(agent_env) }

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
              placer, cloud_properties, client, logger, vsphere_cloud, agent_env, file_provider
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
              resources, cloud_properties, client, logger, vsphere_cloud, agent_env, file_provider
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
              resources, cloud_properties, client, logger, vsphere_cloud, agent_env, file_provider
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
              resources, cloud_properties, client, logger, vsphere_cloud, agent_env, file_provider
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
      let(:agent_env) { instance_double('VSphereCloud::AgentEnv') }
      before { allow(VSphereCloud::AgentEnv).to receive(:new).and_return(agent_env) }
      let(:agent_env_hash) { { 'disks' => { 'persistent' => { disk_cid => 'fake-device-number' } } } }
      before { allow(agent_env).to receive(:get_current_env).and_return(agent_env_hash) }

      before { allow(vsphere_cloud).to receive(:with_thread_name).and_yield }

      let(:disk_model) { class_double('VSphereCloud::Models::Disk').as_stubbed_const }
      let(:disk_cid) { 'fake-disk-cid' }
      let(:disk) do
        instance_double(
          'VSphereCloud::Models::Disk',
          size: 1024,
          uuid: disk_cid,
          datacenter: 'fake-folder/fake-datacenter-name',
          datastore: 'fake-datastore-name',
          path: nil
        )
      end
      before { allow(disk_model).to receive(:first).with(uuid: disk_cid).and_return(disk) }

      let(:vm_cid) { 'fake-vm-cid' }

      let(:vm_folder) { instance_double('VSphereCloud::Resources::Folder', name: 'vm') }

      before { allow(cloud_config).to receive(:datacenter_name).with(no_args).and_return('fake-folder/fake-datacenter-name') }

      let(:vm) { instance_double('VimSdk::Vim::VirtualMachine') }
      before { allow(client).to receive(:find_by_inventory_path).and_return(vm) }

      let(:datastore) { instance_double('VSphereCloud::Resources::Datastore', mob: nil, name: 'fake-datastore-name') }
      before { allow(vsphere_cloud).to receive(:get_vm_host_info).and_return({'datastores' => ['fake-datastore-name']}) }
      before { allow(vsphere_cloud).to receive(:get_primary_datastore).and_return(datastore) }

      let(:device) { instance_double('VimSdk::Vim::Vm::Device::VirtualDisk', controller_key: nil) }
      before { allow(device).to receive(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualDisk).and_return(true) }

      let(:datacenter) { instance_double('VSphereCloud::Resources::Datacenter', disk_path: 'fake-disk-path', name: 'fake-datacenter-name', vm_folder: vm_folder) }
      before do
        allow_any_instance_of(VSphereCloud::Resources).to receive(:datacenters).and_return({ 'fake-folder/fake-datacenter-name' => datacenter })
        allow_any_instance_of(VSphereCloud::Resources).to receive(:place_persistent_datastore).and_return(datastore)
      end

      let(:config_spec) { instance_double('VimSdk::Vim::Vm::ConfigSpec', :device_change= => nil, :device_change => []) }
      before { allow(VimSdk::Vim::Vm::ConfigSpec).to receive(:new).and_return(config_spec) }

      before do
        allow(Dir).to receive(:mktmpdir).and_return('fake-tmp-dir')
        allow_any_instance_of(VSphereCloud::Cloud).to receive(:`).with('tar -C fake-tmp-dir -xzf fake-disk-path 2>&1')

        allow(client).to receive(:find_parent).and_return(:datacenter)
        allow(client).to receive(:get_properties).and_return({'config.hardware.device' => [device], 'name' => 'fake-vm-name'})
        allow(client).to receive(:get_property).with(datastore, VimSdk::Vim::Datastore, 'name').and_return('fake-datastore-name')
      end

      context 'when disk already exists' do
        before { allow(disk).to receive(:path).and_return('fake-disk-path') }

        context 'when disk is in correct datacenter' do
          before do
            allow_any_instance_of(VSphereCloud::Resources).to receive(:validate_persistent_datastore).and_return(true)
            allow_any_instance_of(VSphereCloud::Resources).to receive(:persistent_datastore).and_return(datastore)
          end

          it 'does not update the disk' do
            expect(disk).to_not receive(:save)
            expect(agent_env).to receive(:set_env)
            expect(client).to receive(:reconfig_vm)

            vsphere_cloud.attach_disk('fake-image', disk_cid)
          end
        end

        context 'when disk is in incorrect datacenter' do
          before do
            allow_any_instance_of(VSphereCloud::Resources).to receive(:validate_persistent_datastore).and_return(false)
          end

          context 'when it is configured to copy disk' do
            before { allow(cloud_config).to receive(:copy_disks).and_return(true) }

            it 'copies the disk' do
              expect(client).to receive(:copy_disk)
              expect(disk).to receive(:datacenter=).with('fake-folder/fake-datacenter-name')
              expect(disk).to receive(:datastore=).with('fake-datastore-name')
              expect(disk).to receive(:path=).with('[fake-datastore-name] fake-disk-path/fake-disk-cid')
              expect(disk).to receive(:save)
              expect(agent_env).to receive(:set_env)
              expect(client).to receive(:reconfig_vm)

              vsphere_cloud.attach_disk('fake-image', disk_cid)
            end
          end

          context 'when it is configured to move disk' do
            before { allow(cloud_config).to receive(:copy_disks).and_return(false) }

            it 'moves the disk' do
              expect(client).to receive(:move_disk)
              expect(disk).to receive(:datacenter=).with('fake-folder/fake-datacenter-name')
              expect(disk).to receive(:datastore=).with('fake-datastore-name')
              expect(disk).to receive(:path=).with('[fake-datastore-name] fake-disk-path/fake-disk-cid')
              expect(disk).to receive(:save)

              expect(agent_env).to receive(:set_env)
              expect(client).to receive(:reconfig_vm)

              vsphere_cloud.attach_disk('fake-image', disk_cid)
            end
          end
        end
      end

      context 'when disk does not exist' do
        it 'creates a disk' do
          expect(disk).to receive(:datacenter=).with('fake-folder/fake-datacenter-name')
          expect(disk).to receive(:datastore=).with('fake-datastore-name')
          expect(disk).to receive(:path=).with('[fake-datastore-name] fake-disk-path/fake-disk-cid')
          expect(disk).to receive(:save)

          expect(agent_env).to receive(:set_env)
          actual_device_changes = []
          allow(config_spec).to receive(:device_change).and_return(actual_device_changes)
          expect(client).to receive(:reconfig_vm).with(vm, config_spec)

          vsphere_cloud.attach_disk('fake-image', disk_cid)

          expect(actual_device_changes.size).to eq(1)
          expect(actual_device_changes.first.file_operation).to eq(VimSdk::Vim::Vm::Device::VirtualDeviceSpec::FileOperation::CREATE)
        end
      end
    end
  end
end
