require 'spec_helper'

module VSphereCloud
  describe Cloud do
    subject(:vsphere_cloud) { Cloud.new(config) }

    let(:config) { { fake: 'config' } }
    let(:cloud_config) { instance_double('VSphereCloud::Config', logger: logger, rest_client:nil ).as_null_object }
    let(:logger) { instance_double('Logger', info: nil, debug: nil) }
    let(:client) { instance_double('VSphereCloud::Client', service_content: service_content) }
    let(:service_content) do
      instance_double('VimSdk::Vim::ServiceInstanceContent',
        custom_fields_manager: custom_fields_manager,
        virtual_disk_manager: virtual_disk_manager,
      )
    end
    let(:custom_fields_manager) { instance_double('VimSdk::Vim::CustomFieldsManager') }
    let(:virtual_disk_manager) { instance_double('VimSdk::Vim::VirtualDiskManager') }
    let(:agent_env) { instance_double('VSphereCloud::AgentEnv') }
    before { allow(VSphereCloud::AgentEnv).to receive(:new).and_return(agent_env) }

    let(:cloud_searcher) { instance_double('VSphereCloud::CloudSearcher') }
    before { allow(CloudSearcher).to receive(:new).and_return(cloud_searcher) }

    before do
      allow(Config).to receive(:build).with(config).and_return(cloud_config)
      allow(cloud_config).to receive(:client).and_return(client)
      allow_any_instance_of(Cloud).to receive(:at_exit)
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
          expect(vsphere_cloud).to receive(:get_vm_by_cid).with(vm_id)
          expect(vsphere_cloud.has_vm?(vm_id)).to be(true)
        end
      end

      context 'the vm is not found' do
        it 'returns false' do
          expect(vsphere_cloud).to receive(:get_vm_by_cid).with(vm_id).and_raise(Bosh::Clouds::VMNotFound)
          expect(vsphere_cloud.has_vm?(vm_id)).to be(false)
        end
      end
    end

    describe 'has_disk?' do
      let(:disk_model) { class_double('VSphereCloud::Models::Disk').as_stubbed_const }
      let(:disk_cid) { 'fake-disk-cid' }
      let(:disk) do
        instance_double(
          'VSphereCloud::Models::Disk',
          size: 1024,
          uuid: disk_cid,
          datacenter: disk_datacenter,
          datastore: 'fake-datastore-name',
          path: disk_path
        )
      end

      let(:disk_path) { 'fake-path' }
      let(:disk_datacenter) { 'fake-folder/fake-datacenter-name' }

      context 'when disk is found in database' do
        before { allow(disk_model).to receive(:find).with(uuid: disk_cid).and_return(disk) }

        context 'the disk is found' do
          it 'returns true' do
            expect(client).to receive(:has_disk?).with(
              'fake-path', 'fake-folder/fake-datacenter-name'
            ).and_return(true)

            expect(vsphere_cloud.has_disk?(disk_cid)).to be(true)
          end
        end

        context 'the disk is not found' do
          it 'returns false' do
            expect(client).to receive(:has_disk?).with(
              'fake-path', 'fake-folder/fake-datacenter-name'
            ).and_return(false)

            expect(vsphere_cloud.has_disk?(disk_cid)).to be(false)
          end
        end

        context 'when disk does not have path' do
          let(:disk_path) { nil }

          it 'returns false' do
            expect(vsphere_cloud.has_disk?(disk_cid)).to be(true)
          end
        end

        context 'when disk does not have datacenter' do
          let(:disk_datacenter) { nil }

          it 'returns false' do
            expect(vsphere_cloud.has_disk?(disk_cid)).to be(false)
          end
        end
      end

      context 'when disk is not found in database' do
        before { allow(disk_model).to receive(:find).with(uuid: disk_cid).and_return(nil) }

        it 'returns false' do
          expect(vsphere_cloud.has_disk?(disk_cid)).to be(false)
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

      let(:template_folder) do
        double(:template_folder,
          path_components: ['fake_template_folder'],
          mob: 'fake_template_folder_mob'
        )
      end

      let(:datacenter) do
        double('fake datacenter',
          name: 'fake_datacenter',
          template_folder: template_folder
        )
      end

      let(:cluster) { double('fake cluster', datacenter: datacenter) }
      let(:datastore) { double('fake datastore') }

      context 'when stemcell vm is not found at the expected location' do
        it 'raises an error' do
          allow(client).to receive(:find_by_inventory_path).and_return(nil)

          expect {
            vsphere_cloud.replicate_stemcell(cluster, datastore, 'fake_stemcell_id')
          }.to raise_error(/Could not find stemcell/)
        end
      end

      context 'when stemcell vm resides on a different datastore' do
        before do
          mob = double(:mob, __mo_id__: 'fake_datastore_managed_object_id')
          allow(datastore).to receive(:mob).and_return(mob)
          allow(client).to receive(:find_by_inventory_path).with(
            [
              cluster.datacenter.name,
              'vm',
              ['fake_template_folder'],
              stemcell_id,
            ]
          ).and_return(stemcell_vm)

          allow(cloud_searcher).to receive(:get_property).with(stemcell_vm, anything, 'datastore', anything).and_return('fake_stemcell_datastore')
        end

        it 'searches for stemcell on all cluster datastores' do
          expect(client).to receive(:find_by_inventory_path).with(
            [
              cluster.datacenter.name,
              'vm',
              ['fake_template_folder'],
              "#{stemcell_id} %2f #{datastore.mob.__mo_id__}",
            ]
          ).and_return(double('fake stemcell vm'))

          vsphere_cloud.replicate_stemcell(cluster, datastore, stemcell_id)
        end

        context 'when the stemcell replica is not found in the datacenter' do
          let(:replicated_stemcell) { double('fake_replicated_stemcell') }
          let(:fake_task) { 'fake_task' }


          it 'replicates the stemcell' do
            allow(client).to receive(:find_by_inventory_path).with(
              [
                cluster.datacenter.name,
                'vm',
                ['fake_template_folder'],
                "#{stemcell_id} %2f #{datastore.mob.__mo_id__}",
              ]
            )

            resource_pool = double(:resource_pool, mob: 'fake_resource_pool_mob')
            allow(cluster).to receive(:resource_pool).and_return(resource_pool)
            allow(stemcell_vm).to receive(:clone).with(any_args).and_return(fake_task)
            allow(client).to receive(:wait_for_task).with(fake_task).and_return(replicated_stemcell)
            allow(replicated_stemcell).to receive(:create_snapshot).with(any_args).and_return(fake_task)

            expect(vsphere_cloud.replicate_stemcell(cluster, datastore, stemcell_id)).to eql(replicated_stemcell)
          end
        end
      end

      context 'when stemcell resides on the given datastore' do
        it 'returns the found replica' do
          allow(client).to receive(:find_by_inventory_path).with(any_args).and_return(stemcell_vm)
          allow(cloud_searcher).to receive(:get_property).with(any_args).and_return(datastore)
          allow(datastore).to receive(:mob).and_return(datastore)
          expect(vsphere_cloud.replicate_stemcell(cluster, datastore, stemcell_id)).to eql(stemcell_vm)
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
        allow(device).to receive(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualEthernetCard) { true }
        allow(PathFinder).to receive(:new).and_return(path_finder)
        allow(path_finder).to receive(:path).with(any_args).and_return('fake_network1')
      end

      context 'using a distributed switch' do
        let(:backing) do
          port = double(:port, portgroup_key: 'fake_pgkey1')
          instance_double(
            'VimSdk::Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo',
            port: port
          )
        end

        before do
          allow(backing).to receive(:kind_of?).
            with(VimSdk::Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo).
            and_return(true)
        end

        let(:dvs_index) { { 'fake_pgkey1' => 'fake_network1' } }

        it 'generates the network env' do
          expect(vsphere_cloud.generate_network_env(devices, networks, dvs_index)).to eq(expected_output)
        end
      end

      context 'using a standard switch' do
        let(:backing) { double(network: 'fake_network1') }

        it 'generates the network env' do
          allow(backing).to receive(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo) { false }

          expect(vsphere_cloud.generate_network_env(devices, networks, dvs_index)).to eq(expected_output)
        end
      end

      context 'passing in device that is not a VirtualEthernetCard' do
        let(:devices) { [device, double()] }
        let(:backing) { double(network: 'fake_network1') }

        it 'ignores non VirtualEthernetCard devices' do
          allow(backing).to receive(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo) { false }

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
            allow(PathFinder).to receive(:new).and_return(path_finder)
            allow(path_finder).to receive(:path).with(fake_network_object).and_return('networks/fake_network1')

            allow(backing).to receive(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualEthernetCard::DistributedVirtualPortBackingInfo) { false }

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
          allow(cloud_searcher).to receive(:get_properties).with(network, VimSdk::Vim::Dvs::DistributedVirtualPortgroup,
                                            ['config.key', 'config.distributedVirtualSwitch'],
                                            ensure_all: true).and_return(portgroup_properties)

          allow(cloud_searcher).to receive(:get_property).with(switch, VimSdk::Vim::DistributedVirtualSwitch,
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
                                                   master_vm_folder: master_vm_folder,
                                                   master_template_folder: master_template_folder) }
      let(:master_vm_folder) do
        instance_double('VSphereCloud::Resources::Folder',
          path: 'fake-vm-folder-path',
          mob: vm_folder_mob
        )
      end
      let(:vm_folder_mob) { double('fake folder mob', child_entity: [subfolder]) }
      let(:subfolder) { double('fake subfolder', child_entity: vms) }
      let(:vms) { ['fake vm 1', 'fake vm 2'] }

      let(:master_template_folder) do
        instance_double('VSphereCloud::Resources::Folder',
          path: 'fake-template-folder-path',
          mob: template_folder_mob
        )
      end
      let(:template_folder_mob) { double('fake template folder mob', child_entity: [template_subfolder_mob]) }
      let(:template_subfolder_mob) { double('fake template subfolder', child_entity: stemcells) }
      let(:stemcells) { ['fake stemcell 1', 'fake stemcell 2'] }

      before { allow(Resources).to receive(:new).and_return(resources) }

      it 'returns all vms in vm_folder of datacenter and all stemcells in template_folder' do
        expect(vsphere_cloud.get_vms).to eq(['fake vm 1', 'fake vm 2', 'fake stemcell 1', 'fake stemcell 2'])
      end

      context 'when multiple datacenters exist in config' do
        let(:resources) { double('fake resources', datacenters: { key1: datacenter, key2: datacenter2 }) }

        let(:datacenter2) { double('another fake datacenter', name: 'fake datacenter 2',
                                                              master_vm_folder: master_vm_folder2,
                                                              master_template_folder: master_template_folder2) }
        let(:master_vm_folder2) do
          instance_double('VSphereCloud::Resources::Folder',
            path: 'another-fake-vm-folder-path',
            mob: vm_folder2_mob
          )
        end
        let(:vm_folder2_mob) { double('another fake folder mob', child_entity: [subfolder2]) }
        let(:subfolder2) { double('another fake subfolder', child_entity: vms2) }
        let(:vms2) { ['fake vm 3', 'fake vm 4'] }

        let(:master_template_folder2) do
          instance_double('VSphereCloud::Resources::Folder',
            path: 'another-fake-template-folder-path',
            mob: template_folder2_mob
          )
        end
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

        context 'using a placer' do
          let(:clusters) {
            [
              { 'BOSH_CL' => { 'drs_rules' => 'fake-drs-rules' }, },
              { 'BOSH_CL2' => {} }
            ]
          }

          let(:datacenters) {
            [{
              'name' => 'BOSH_DC',
              'clusters' => clusters,
            }]
          }

          let(:placer) { double('placer') }
          let(:cluster) { double('cluster', mob: nil) }
          let(:datacenter) { double('datacenter') }

          before do
            allow(Resources::Datacenter).to receive(:new).with(cloud_config).and_return(datacenter)
            allow(cloud_properties).to receive(:fetch).with('datacenters', []).and_return(datacenters)
            allow(cloud_config).to receive(:datacenter_name).with(no_args).and_return(datacenters.first['name'])
            allow(datacenter).to receive(:clusters).with(no_args).and_return({'BOSH_CL' => cluster})

            placer_class = class_double('VSphereCloud::FixedClusterPlacer').as_stubbed_const
            allow(placer_class).to receive(:new).with(cluster, 'fake-drs-rules').and_return(placer)
          end

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
              placer, cloud_properties, client, cloud_searcher, logger, vsphere_cloud, agent_env, file_provider
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
              resources, cloud_properties, client, cloud_searcher, logger, vsphere_cloud, agent_env, file_provider
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
              resources, cloud_properties, client, cloud_searcher, logger, vsphere_cloud, agent_env, file_provider
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
              resources, cloud_properties, client, cloud_searcher, logger, vsphere_cloud, agent_env, file_provider
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
      let(:resources) { double('VSphereCloud::Resources') }
      before { allow(VSphereCloud::Resources).to receive(:new).and_return(resources) }

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
      let(:vm_folder) { instance_double('VSphereCloud::Resources::Folder', path: ['vm']) }

      before { allow(cloud_config).to receive(:datacenter_name).with(no_args).and_return('fake-folder/fake-datacenter-name') }

      let(:vm) { instance_double('VimSdk::Vim::VirtualMachine') }
      let(:vm_location) { double(:vm_location) }
      before do
        allow(client).to receive(:find_by_inventory_path).and_return(vm)
        allow(vsphere_cloud).to receive(:get_vm_by_cid).and_return(vm)
        allow(vsphere_cloud).to receive(:get_vm_location).and_return(vm_location)
      end

      let(:host_info) { double(:host_info) }
      before { allow(vsphere_cloud).to receive(:get_vm_host_info).with(vm).and_return(host_info)}

      let(:controller_key) { double(:controller_key) }
      let(:device) { instance_double('VimSdk::Vim::Vm::Device::VirtualDisk', controller_key: controller_key) }
      before { allow(device).to receive(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualDisk).and_return(true) }

      let(:config_spec) { instance_double('VimSdk::Vim::Vm::ConfigSpec', :device_change= => nil, :device_change => []) }
      before { allow(VimSdk::Vim::Vm::ConfigSpec).to receive(:new).and_return(config_spec) }

      before do
        allow(client).to receive(:find_parent).and_return(:datacenter)
        allow(cloud_searcher).to receive(:get_properties).and_return({'config.hardware.device' => [device], 'name' => 'fake-vm-name'})
      end

      let(:persistent_disk) { instance_double('VSphereCloud::PersistentDisk') }
      before do
        allow(VSphereCloud::PersistentDisk).to receive(:new).with(disk_cid, cloud_searcher, resources, client, logger).
          and_return(persistent_disk)
      end

      before { allow(cloud_config).to receive(:copy_disks).and_return(true) }

      let(:disk_spec) { double(:disk_spec, device: double(:device, unit_number: 'fake-unit-number')) }

      it 'updates persistent disk' do
        expect(persistent_disk).to receive(:create_spec).
          with('fake-folder/fake-datacenter-name', host_info, controller_key, true).and_return(disk_spec)

        expect(client).to receive(:reconfig_vm) do |reconfig_vm, vm_config|
          expect(reconfig_vm).to eq(vm)
          expect(vm_config.device_change).to include(disk_spec)
        end

        expect(vsphere_cloud).to receive(:fix_device_unit_numbers)

        expect(agent_env).to receive(:set_env) do|env_vm, env_location, env|
          expect(env_vm).to eq(vm)
          expect(env_location).to eq(vm_location)
          expect(env['disks']['persistent']['fake-disk-cid']).to eq('fake-unit-number')
        end

        vsphere_cloud.attach_disk('fake-image', disk_cid)
      end
    end

    describe '#delete_vm' do
      let(:vm) { instance_double('VimSdk::Vim::VirtualMachine') }
      before { allow(vsphere_cloud).to receive(:get_vm_by_cid).with('fake-vm-id').and_return(vm) }

      let(:datacenter) { instance_double('VimSdk::Vim::Datacenter') }
      before { allow(client).to receive(:find_parent).with(vm, VimSdk::Vim::Datacenter).and_return(datacenter) }

      let(:devices) { [virtual_disk_device] }
      before do
        allow(cloud_searcher).to receive(:get_properties).with(
          vm,
          VimSdk::Vim::VirtualMachine,
          ['runtime.powerState', 'runtime.question', 'config.hardware.device', 'name'],
          ensure: ['config.hardware.device']
        ).and_return(
          {
            'runtime.question' => false,
            'runtime.powerState' => VimSdk::Vim::VirtualMachine::PowerState::POWERED_OFF,
            'config.hardware.device' => devices,
            'name' => 'fake-vm-name'
          }
        )
        allow(client).to receive(:get_cdrom_device).and_return(nil)
      end

      let(:virtual_disk_device) { instance_double('VimSdk::Vim::Vm::Device::VirtualDisk', backing: virtual_disk_backing) }
      before do
        allow(virtual_disk_device).to receive(:kind_of?).and_return(false)
        allow(virtual_disk_device).to receive(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualDisk).and_return(true)
      end

      let(:virtual_disk_backing) do
        instance_double('VimSdk::Vim::Vm::Device::VirtualDisk::FlatVer2BackingInfo',
          datastore: datastore,
          disk_mode: VimSdk::Vim::Vm::Device::VirtualDiskOption::DiskMode::INDEPENDENT_NONPERSISTENT
        )
      end

      let(:datastore) { instance_double('VimSdk::Vim::Datastore') }
      before do
        allow(cloud_searcher).to receive(:get_property).
          with(datastore, VimSdk::Vim::Datastore, 'name').
          and_return('fake-datastore-name')
      end

      before { allow(client).to receive(:delete_vm).with(vm) }

      it 'deletes vm' do
        expect(client).to receive(:delete_vm).with(vm)
        vsphere_cloud.delete_vm('fake-vm-id')
      end

      context 'vm has cdrom' do
        let(:cdrom_device) { instance_double('VimSdk::Vim::Vm::Device::VirtualCdrom') }
        let(:devices) { [virtual_disk_device, cdrom_device] }

        before do
          allow(cdrom_device).to receive(:kind_of?).and_return(false)
          allow(cdrom_device).to receive(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualCdrom).and_return(true)
        end

        before { allow(client).to receive(:get_cdrom_device).and_return(cdrom_device) }

        it 'cleans the agent environment, before deleting the vm' do
          expect(agent_env).to receive(:clean_env).with(vm).ordered
          expect(client).to receive(:delete_vm).with(vm).ordered

          vsphere_cloud.delete_vm('fake-vm-id')
        end
      end
    end

    describe '#detach_disk' do
      let(:vm) { instance_double('VimSdk::Vim::VirtualMachine') }

      it 'raises an error if disk is not found in vSphere database' do
        expect {
          vsphere_cloud.detach_disk('vm-cid', 'non-existent-disk-cid')
        }.to raise_error /Disk not found: non-existent-disk-cid/
      end

      context 'when disk exists in database' do
        let!(:disk) do
          Models::Disk.create(uuid: 'disk-cid', size: 100, path: 'fake-disk-path')
        end

        before do
          allow(vsphere_cloud).to receive(:get_vm_by_cid).with('vm-cid').and_return(vm)
          allow(cloud_searcher).to receive(:get_property).with(
            vm,
            VimSdk::Vim::VirtualMachine,
            'config.hardware.device',
            ensure_all: true
          ).and_return(devices)

          allow(vsphere_cloud).to receive(:get_vm_location).and_return(vm_location)

          allow(agent_env).to receive(:get_current_env).with(vm, 'fake-datacenter-name').
            and_return(env)
          allow(agent_env).to receive(:set_env)
          allow(client).to receive(:reconfig_vm) do
            allow(cloud_searcher).to receive(:get_property).with(vm, VimSdk::Vim::VirtualMachine, 'config.hardware.device', anything).and_return([attached_disk], [])
          end
        end

        after { disk.destroy }

        let(:env) do
          {'disks' => {'persistent' => {'disk-cid' => 'fake-data'}}}
        end

        let(:vm_location) do
          {
            datacenter: 'fake-datacenter-name',
            datastore: 'fake-datastore-name',
            vm: 'fake-vm-name'
          }
        end

        let(:attached_disk) do
          disk = VimSdk::Vim::Vm::Device::VirtualDisk.new
          disk.backing = double(:backing, file_name: 'fake-disk-path/disk-cid.vmdk')
          disk
        end

        let(:devices) { [attached_disk] }

        it 'updates VM with new settings' do
          expect(agent_env).to receive(:set_env).with(
            vm,
            vm_location,
            {'disks' => {'persistent' => {}}}
          )
          vsphere_cloud.detach_disk('vm-cid', 'disk-cid')
        end

        context 'when old settings do not contain disk to be detached' do
          let(:env) do
            {'disks' => {'persistent' => {}}}
          end

          it 'does not update VM with new setting' do
            expect(agent_env).to_not receive(:set_env)
            vsphere_cloud.detach_disk('vm-cid', 'disk-cid')
          end
        end

        context 'when disk is not attached' do
          let(:devices) { [] }

          it 'updates VM with new settings' do
            expect(agent_env).to receive(:set_env).with(
              vm,
              vm_location,
              {'disks' => {'persistent' => {}}}
            )
            expect {
              vsphere_cloud.detach_disk('vm-cid', 'disk-cid')
            }.to raise_error(Bosh::Clouds::DiskNotAttached)
          end

          it 'raises an error if disk is not attached' do
            expect {
              vsphere_cloud.detach_disk('vm-cid', 'disk-cid')
            }.to raise_error(Bosh::Clouds::DiskNotAttached)
          end
        end

        it 'reconfigures VM with new config' do
          expect(client).to receive(:reconfig_vm) do |config_vm, config|
            expect(config_vm).to eq(vm)
            expect(config.device_change.first.device).to eq(attached_disk)
            expect(config.device_change.first.operation).to eq(
              VimSdk::Vim::Vm::Device::VirtualDeviceSpec::Operation::REMOVE
            )
            allow(cloud_searcher).to receive(:get_property).with(vm, VimSdk::Vim::VirtualMachine, 'config.hardware.device', anything).and_return([attached_disk], [])
          end

          vsphere_cloud.detach_disk('vm-cid', 'disk-cid')
        end

        context 'when vm has multiple disks attached' do
          let(:second_disk) do
            disk = VimSdk::Vim::Vm::Device::VirtualDisk.new
            disk.backing = double(:backing, file_name: 'second-disk-path/second-cid.vmdk')
            disk
          end

          let(:devices) { [attached_disk, second_disk] }

          it 'only detaches disk that matches disk id and does not detach other disks' do
            expect(client).to receive(:reconfig_vm) do |config_vm, config|
              expect(config_vm).to eq(vm)
              expect(config.device_change.first.device).to eq(attached_disk)
              expect(config.device_change.first.operation).to eq(
                VimSdk::Vim::Vm::Device::VirtualDeviceSpec::Operation::REMOVE
              )
              expect(config.device_change.length).to eq 1
              allow(cloud_searcher).to receive(:get_property).with(vm, VimSdk::Vim::VirtualMachine, 'config.hardware.device', anything).and_return([attached_disk, second_disk], [second_disk])
            end

            vsphere_cloud.detach_disk('vm-cid', 'disk-cid')
          end

          it 'waits until the expected disk was detached' do
            expect(client).to receive(:reconfig_vm) do |config_vm, config|
              expect(config_vm).to eq(vm)
              expect(config.device_change.first.device).to eq(attached_disk)
              expect(config.device_change.first.operation).to eq(
                VimSdk::Vim::Vm::Device::VirtualDeviceSpec::Operation::REMOVE
              )
              expect(config.device_change.length).to eq 1
              allow(cloud_searcher).to receive(:get_property).with(vm, VimSdk::Vim::VirtualMachine, 'config.hardware.device', anything).and_return(
                [second_disk, attached_disk],
                [second_disk, attached_disk],
                [second_disk, attached_disk],
                [second_disk, attached_disk],
                [second_disk]).exactly(5).times
            end

            vsphere_cloud.detach_disk('vm-cid', 'disk-cid')
          end
        end
      end
    end

    describe '#configure_networks' do
      let(:vm) { instance_double('VimSdk::Vim::VirtualMachine') }
      before { allow(vsphere_cloud).to receive(:get_vm_by_cid).with('fake-vm-id').and_return(vm) }
      let(:networks) do
        {
          'default' => {
            'cloud_properties' => {
              'name' => 'fake-network-name'
            }
          }
        }
      end

      let(:devices) { [VimSdk::Vim::Vm::Device::VirtualPCIController.new(key: 'fake-pci-key')] }
      before do
        allow(cloud_searcher).to receive(:get_property).with(
          vm,
          VimSdk::Vim::VirtualMachine,
          'config.hardware.device',
          ensure_all: true
        ).and_return(devices)
      end

      before { allow(cloud_config).to receive(:datacenter_name).and_return('fake-datacenter-name') }
      let(:datacenter) { instance_double('VimSdk::Vim::Datacenter') }
      before { allow(client).to receive(:find_parent).with(vm, VimSdk::Vim::Datacenter).and_return(datacenter) }

      let(:network_mob) { double(:network_mob) }
      before do
        allow(client).to receive(:find_by_inventory_path).with([
          'fake-datacenter-name',
          'network',
          'fake-network-name'
        ]).and_return(network_mob)
      end

      let(:nic_config) { double(:nic_config) }
      before do
        allow(vsphere_cloud).to receive(:create_nic_config_spec).with(
          'fake-network-name',
          network_mob,
          'fake-pci-key',
          {}
        ).and_return(nic_config)

        allow(vsphere_cloud).to receive(:fix_device_unit_numbers).with(
          devices,
          [nic_config]
        )
      end

      before do
        allow(agent_env).to receive(:get_current_env).and_return(
          { 'old-key' => 'old-value' }
        )

        allow(vsphere_cloud).to receive(:generate_network_env).and_return('fake-network-env')
        allow(vsphere_cloud).to receive(:get_vm_location).and_return('fake-vm-location')
      end

      it 'sends shutdown command to vm' do
        allow(cloud_searcher).to receive(:get_property).with(
          vm,
          VimSdk::Vim::VirtualMachine,
          'runtime.powerState'
        ).and_return(VimSdk::Vim::VirtualMachine::PowerState::POWERED_OFF)

        expect(vm).to receive(:shutdown_guest)

        expect(client).to receive(:reconfig_vm) do |reconfig_vm, vm_config|
          expect(reconfig_vm).to eq(vm)
          expect(vm_config.device_change).to eq([nic_config])
        end

        expect(agent_env).to receive(:set_env).with(
          vm,
          'fake-vm-location',
          {
            'old-key' => 'old-value',
            'networks' => 'fake-network-env'
          }
        )

        expect(client).to receive(:power_on_vm).with(datacenter, vm)

        vsphere_cloud.configure_networks('fake-vm-id', networks)
      end

      it 'waits for vm to shutdown for 60 seconds' do
        expect(cloud_searcher).to receive(:get_property).with(
          vm,
          VimSdk::Vim::VirtualMachine,
          'runtime.powerState'
        ).and_return(
          VimSdk::Vim::VirtualMachine::PowerState::POWERED_ON,
          VimSdk::Vim::VirtualMachine::PowerState::POWERED_ON,
          VimSdk::Vim::VirtualMachine::PowerState::POWERED_OFF
        ).exactly(3).times

        expect(vsphere_cloud).to receive(:wait_until_off).with(vm, 60).and_call_original

        expect(vm).to receive(:shutdown_guest).ordered
        expect(client).to receive(:reconfig_vm).ordered
        expect(agent_env).to receive(:set_env).ordered
        expect(client).to receive(:power_on_vm).with(datacenter, vm)

        vsphere_cloud.configure_networks('fake-vm-id', networks)
      end

      it 'sends poweroff to vm if did not shutdown' do
        expect(vsphere_cloud).to receive(:wait_until_off).with(vm, 60).
          and_raise(VSphereCloud::Cloud::TimeoutException)
        expect(client).to receive(:power_off_vm).with(vm)

        expect(vm).to receive(:shutdown_guest).ordered
        expect(client).to receive(:reconfig_vm).ordered
        expect(agent_env).to receive(:set_env).ordered
        expect(client).to receive(:power_on_vm).with(datacenter, vm)

        vsphere_cloud.configure_networks('fake-vm-id', networks)
      end
    end

    describe '#delete_disk' do
      context 'when disk is in database' do
        before do
          Models::Disk.create(
            uuid: 'fake-disk-uuid',
            size: 100,
            datacenter: 'fake-datacenter',
            path: 'test-path'
          )
        end

        after do
          disk = Models::Disk.find(uuid: 'fake-disk-uuid')
          disk.destroy if disk
        end

        context 'when disk is not in the cloud' do
          before do
            allow(vsphere_cloud).to receive(:has_disk?).with('fake-disk-uuid').and_return(false)
          end

          it 'raises DiskNotFound' do
            expect {
              vsphere_cloud.delete_disk('fake-disk-uuid')
            }.to raise_error(Bosh::Clouds::DiskNotFound)
          end
        end

        context 'when disk is in the cloud' do
          before do
            allow(vsphere_cloud).to receive(:has_disk?).with('fake-disk-uuid').and_return(true)
          end

          context 'when disk datacenter cannot be found' do
            before do
              allow(client).to receive(:find_by_inventory_path).with('fake-datacenter').and_return(nil)
            end

            it 'raises DiskNotFound' do
              expect {
                vsphere_cloud.delete_disk('fake-disk-uuid')
              }.to raise_error(Bosh::Clouds::DiskNotFound)
            end
          end

          context 'when disk datacenter is found' do
            before do
              allow(client).to receive(:find_by_inventory_path).with('fake-datacenter').and_return(datacenter)
            end
            let(:datacenter) { double(:datacenter) }

            it 'deletes disk' do
              expect(client).to receive(:delete_disk).with(datacenter, 'test-path')
              vsphere_cloud.delete_disk('fake-disk-uuid')
            end
          end
        end
      end

      context 'when disk is not in database' do
        it 'raises an error' do
          expect {
            vsphere_cloud.delete_disk('fake-disk-uuid')
          }.to raise_error
        end
      end
    end

    describe '#create_disk' do
      let(:disk) { instance_double('VSphereCloud::Disk', uuid: 'fake-disk-uuid') }
      let(:disk_provider) { instance_double('VSphereCloud::DiskProvider') }
      before do
        Models::Disk.delete
        allow(VSphereCloud::DiskProvider).to receive(:new).and_return(disk_provider)
        allow(disk_provider).to receive(:create).with(1048576).and_return(disk)
      end

      it 'creates disk with disk provider' do
        expect(disk_provider).to receive(:create).with(1048576).and_return(disk)
        vsphere_cloud.create_disk(1024, {})
      end

      it 'creates disk in database' do
        vsphere_cloud.create_disk(1024, {})
        created_disk = Models::Disk.first
        expect(created_disk.size).to eq(1024)
        expect(created_disk.uuid).to eq('fake-disk-uuid')
      end
    end
  end
end
