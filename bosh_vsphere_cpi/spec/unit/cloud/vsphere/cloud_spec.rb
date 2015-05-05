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

    let(:datacenter) { instance_double('VSphereCloud::Resources::Datacenter', name: 'fake-datacenter', clusters: {}) }
    before { allow(Resources::Datacenter).to receive(:new).and_return(datacenter) }
    let(:disk_provider) { instance_double('VSphereCloud::DiskProvider') }
    before { allow(VSphereCloud::DiskProvider).to receive(:new).and_return(disk_provider) }
    let(:vm_provider) { instance_double('VSphereCloud::VMProvider') }
    before { allow(VSphereCloud::VMProvider).to receive(:new).and_return(vm_provider) }
    let(:vm) { instance_double('VSphereCloud::Resources::VM', mob: vm_mob, reload: nil, cid: 'vm-id') }
    let(:vm_mob) { instance_double('VimSdk::Vim::VirtualMachine') }
    before { allow(vm_provider).to receive(:find).with('vm-id').and_return(vm) }

    describe 'has_vm?' do
      context 'the vm is found' do
        it 'returns true' do
          expect(vsphere_cloud.has_vm?('vm-id')).to be(true)
        end
      end

      context 'the vm is not found' do
        it 'returns false' do
          allow(vm_provider).to receive(:find).with('vm-id').and_raise(Bosh::Clouds::VMNotFound)
          expect(vsphere_cloud.has_vm?('vm-id')).to be(false)
        end
      end
    end

    describe 'has_disk?' do
      before { allow(datacenter).to receive(:persistent_datastores).and_return('fake-persistent-datastores') }

      context 'when disk is found' do
        let(:disk) { instance_double('VSphereCloud::Resources::Disk', path: 'disk-path') }
        before do
          allow(disk_provider).to receive(:find).with('fake-disk-uuid').and_return(disk)
        end

        it 'returns true' do
          expect(vsphere_cloud.has_disk?('fake-disk-uuid')).to be(true)
        end
      end

      context 'when disk is not found' do
        before do
          allow(disk_provider).to receive(:find).
            with('fake-disk-uuid').
            and_raise Bosh::Clouds::DiskNotFound.new(false)
        end

        it 'returns false' do
          expect(vsphere_cloud.has_disk?('fake-disk-uuid')).to be(false)
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
          template_folder: template_folder,
          clusters: {}
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
      before do
        allow(datacenter).to receive(:master_vm_folder).and_return(master_vm_folder)
        allow(datacenter).to receive(:master_template_folder).and_return(master_template_folder)
      end

      let(:master_vm_folder) do
        instance_double('VSphereCloud::Resources::Folder',
          path: 'fake-vm-folder-path',
          mob: vm_folder_mob
        )
      end
      let(:vm_folder_mob) { double('fake folder mob', child_entity: [subfolder]) }
      let(:subfolder) { double('fake subfolder', child_entity: [vm_mob1, vm_mob2]) }
      let(:vm_mob1) { instance_double(VimSdk::Vim::VirtualMachine, name: 'fake-vm-1') }
      let(:vm_mob2) { instance_double(VimSdk::Vim::VirtualMachine, name: 'fake-vm-2') }

      let(:master_template_folder) do
        instance_double('VSphereCloud::Resources::Folder',
          path: 'fake-template-folder-path',
          mob: template_folder_mob
        )
      end
      let(:template_folder_mob) { double('fake template folder mob', child_entity: [template_subfolder_mob]) }
      let(:template_subfolder_mob) { double('fake template subfolder', child_entity: [stemcell_mob1, stemcell_mob2]) }
      let(:stemcell_mob1) { instance_double(VimSdk::Vim::VirtualMachine, name: 'fake-stemcell-1') }
      let(:stemcell_mob2) { instance_double(VimSdk::Vim::VirtualMachine, name: 'fake-stemcell-2') }

      it 'returns all vms in vm_folder of datacenter and all stemcells in template_folder' do
        vms = vsphere_cloud.get_vms
        expect(vms.map(&:cid)).to eq(['fake-vm-1', 'fake-vm-2', 'fake-stemcell-1', 'fake-stemcell-2'])
        expect(vms.map(&:mob)).to eq([vm_mob1, vm_mob2, stemcell_mob1, stemcell_mob2])
      end
    end

    describe '#create_vm' do
      let(:resources) { double('resources') }
      before { allow(Resources).to receive(:new).and_return(resources) }

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
            allow_any_instance_of(Resources::ClusterProvider).to receive(:find).and_return(cluster)

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
              placer, cloud_properties, client, cloud_searcher, logger, vsphere_cloud, agent_env, file_provider, disk_provider
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
              resources, cloud_properties, client, cloud_searcher, logger, vsphere_cloud, agent_env, file_provider, disk_provider
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
              resources, cloud_properties, client, cloud_searcher, logger, vsphere_cloud, agent_env, file_provider, disk_provider
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
              resources, cloud_properties, client, cloud_searcher, logger, vsphere_cloud, agent_env, file_provider, disk_provider
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
      let(:agent_env_hash) { { 'disks' => { 'persistent' => { 'disk-cid' => 'fake-device-number' } } } }
      before { allow(agent_env).to receive(:get_current_env).and_return(agent_env_hash) }

      let(:vm_location) { double(:vm_location) }
      before { allow(vsphere_cloud).to receive(:get_vm_location).and_return(vm_location) }

      before do
        allow(datacenter).to receive(:clusters).and_return({'fake-cluster-name' => cluster})
        allow(vm).to receive(:cluster).and_return('fake-cluster-name')
        allow(vm).to receive(:accessible_datastores).and_return(['fake-datastore-name'])
        allow(vm).to receive(:system_disk).and_return(double(:system_disk, controller_key: 'fake-controller-key'))
      end

      let(:datastore) { instance_double('VSphereCloud::Resources::Datastore', name: 'fake-datastore')}
      let(:cluster) { instance_double('VSphereCloud::Resources::Cluster') }
      let(:disk) { VSphereCloud::Resources::Disk.new('fake-disk-cid', 1024, datastore, 'fake-disk-path') }

      it 'updates persistent disk' do
        expect(disk_provider).to receive(:find_and_move).
          with('disk-cid', cluster, datacenter, ['fake-datastore-name']).
          and_return(disk)

        expect(client).to receive(:reconfig_vm) do |reconfig_vm, vm_config|
          expect(reconfig_vm).to eq(vm_mob)
          expect(vm_config.device_change.size).to eq(1)
          disk_spec = vm_config.device_change.first
          expect(disk_spec.device.capacity_in_kb).to eq(1024 * 1024)
          expect(disk_spec.device.backing.datastore).to eq(datastore.name)
          expect(disk_spec.device.controller_key).to eq('fake-controller-key')
        end

        expect(vm).to receive(:fix_device_unit_numbers)

        expect(agent_env).to receive(:set_env) do|env_vm, env_location, env|
          expect(env_vm).to eq(vm_mob)
          expect(env_location).to eq(vm_location)
        end

        vsphere_cloud.attach_disk('vm-id', 'disk-cid')
      end
    end

    describe '#delete_vm' do
      before do
        allow(vm).to receive(:persistent_disks).and_return([])
        allow(vm).to receive(:cdrom).and_return(nil)
      end

      it 'deletes vm' do
        expect(vm).to receive(:power_off)
        expect(vm).to receive(:delete)
        vsphere_cloud.delete_vm('vm-id')
      end

      context 'when vm has persistent disks' do
        let(:disk) { instance_double('VimSdk::Vim::Vm::Device::VirtualDisk', backing: double(:backing, file_name: 'fake-file_name')) }
        before { allow(vm).to receive(:persistent_disks).and_return([disk]) }

        it 'detaches persistent disks' do
          expect(client).to receive(:reconfig_vm) do |mob, spec|
            expect(mob).to equal(vm_mob)
            expect(spec.device_change.first.device).to eq(disk)
            expect(spec.device_change.first.operation).to eq(VimSdk::Vim::Vm::Device::VirtualDeviceSpec::Operation::REMOVE)
          end
          expect(vm).to receive(:power_off)
          expect(vm).to receive(:delete)

          vsphere_cloud.delete_vm('vm-id')
        end
      end

      context 'vm has cdrom' do
        let(:cdrom) { instance_double('VimSdk::Vim::Vm::Device::VirtualCdrom') }
        before { allow(vm).to receive(:cdrom).and_return(cdrom) }

        it 'cleans the agent environment, before deleting the vm' do
          expect(agent_env).to receive(:clean_env).with(vm_mob).ordered

          expect(vm).to receive(:power_off)
          expect(vm).to receive(:delete)

          vsphere_cloud.delete_vm('vm-id')
        end
      end
    end

    describe '#detach_disk' do
      it 'raises an error if disk is not found' do
        allow(disk_provider).to receive(:find).with('non-existent-disk-cid').
          and_raise(Bosh::Clouds::DiskNotFound.new(false))
        expect {
          vsphere_cloud.detach_disk('vm-id', 'non-existent-disk-cid')
        }.to raise_error Bosh::Clouds::DiskNotFound
      end

      context 'when disk exists' do
        before do
          found_disk = instance_double(VSphereCloud::Resources::Disk, cid: 'disk-cid')
          allow(disk_provider).to receive(:find).with('disk-cid').and_return(found_disk)
          allow(cloud_searcher).to receive(:get_property).with(
            vm_mob,
            VimSdk::Vim::VirtualMachine,
            'config.hardware.device',
            ensure_all: true
          ).and_return(devices)

          allow(vsphere_cloud).to receive(:get_vm_location).and_return(vm_location)

          allow(agent_env).to receive(:get_current_env).with(vm_mob, 'fake-datacenter-name').
            and_return(env)
          allow(agent_env).to receive(:set_env)
          allow(client).to receive(:reconfig_vm) do
            allow(cloud_searcher).to receive(:get_property).with(vm, VimSdk::Vim::VirtualMachine, 'config.hardware.device', anything).and_return([attached_disk], [])
          end
          allow(vm).to receive(:disk_by_cid).with('disk-cid').and_return(attached_disk, nil)
        end

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
            vm_mob,
            vm_location,
            {'disks' => {'persistent' => {}}}
          )
          vsphere_cloud.detach_disk('vm-id', 'disk-cid')
        end

        context 'when old settings do not contain disk to be detached' do
          let(:env) do
            {'disks' => {'persistent' => {}}}
          end

          it 'does not update VM with new setting' do
            expect(agent_env).to_not receive(:set_env)
            vsphere_cloud.detach_disk('vm-id', 'disk-cid')
          end
        end

        context 'when disk is not attached' do
          before do
            allow(vm).to receive(:disk_by_cid).with('disk-cid').and_return(nil)
          end

          it 'updates VM with new settings' do
            expect(agent_env).to receive(:set_env).with(
              vm_mob,
              vm_location,
              {'disks' => {'persistent' => {}}}
            )
            expect {
              vsphere_cloud.detach_disk('vm-id', 'disk-cid')
            }.to raise_error(Bosh::Clouds::DiskNotAttached)
          end

          it 'raises an error if disk is not attached' do
            expect {
              vsphere_cloud.detach_disk('vm-id', 'disk-cid')
            }.to raise_error(Bosh::Clouds::DiskNotAttached)
          end
        end

        it 'reconfigures VM with new config' do
          expect(client).to receive(:reconfig_vm) do |config_vm, config|
            expect(config_vm).to eq(vm_mob)
            expect(config.device_change.first.device).to eq(attached_disk)
            expect(config.device_change.first.operation).to eq(
              VimSdk::Vim::Vm::Device::VirtualDeviceSpec::Operation::REMOVE
            )
            allow(cloud_searcher).to receive(:get_property).with(vm, VimSdk::Vim::VirtualMachine, 'config.hardware.device', anything).and_return([attached_disk], [])
          end

          vsphere_cloud.detach_disk('vm-id', 'disk-cid')
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
              expect(config_vm).to eq(vm_mob)
              expect(config.device_change.first.device).to eq(attached_disk)
              expect(config.device_change.first.operation).to eq(
                VimSdk::Vim::Vm::Device::VirtualDeviceSpec::Operation::REMOVE
              )
              expect(config.device_change.length).to eq 1
              allow(cloud_searcher).to receive(:get_property).with(vm, VimSdk::Vim::VirtualMachine, 'config.hardware.device', anything).and_return([attached_disk, second_disk], [second_disk])
            end

            vsphere_cloud.detach_disk('vm-id', 'disk-cid')
          end

          it 'waits until the expected disk was detached' do
            expect(client).to receive(:reconfig_vm) do |config_vm, config|
              expect(config_vm).to eq(vm_mob)
              expect(config.device_change.first.device).to eq(attached_disk)
              expect(config.device_change.first.operation).to eq(
                VimSdk::Vim::Vm::Device::VirtualDeviceSpec::Operation::REMOVE
              )
              expect(config.device_change.length).to eq 1
            end

            vsphere_cloud.detach_disk('vm-id', 'disk-cid')
          end
        end
      end
    end

    describe '#configure_networks' do
      let(:networks) do
        {
          'default' => {
            'cloud_properties' => {
              'name' => 'fake-network-name'
            }
          }
        }
      end

      before do
        allow(vm).to receive(:nics).and_return([])
        allow(vm).to receive(:devices).and_return([])
        allow(vm).to receive(:pci_controller).and_return(double(:pci_controller, key: 'fake-pci-key'))
      end

      let(:network_mob) { double(:network_mob) }
      before do
        allow(client).to receive(:find_by_inventory_path).with([
          'fake-datacenter',
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
      end

      before do
        allow(agent_env).to receive(:get_current_env).and_return(
          { 'old-key' => 'old-value' }
        )

        allow(vsphere_cloud).to receive(:generate_network_env).and_return('fake-network-env')
        allow(vsphere_cloud).to receive(:get_vm_location).and_return('fake-vm-location')

        allow(cloud_searcher).to receive(:get_property).with(
          vm_mob,
          VimSdk::Vim::VirtualMachine,
          'config.hardware.device',
          ensure_all: true
        ).and_return([])
      end

      it 'shuts down and reconfigures vm' do
        expect(vm).to receive(:shutdown).ordered
        expect(vm).to receive(:fix_device_unit_numbers).ordered

        expect(client).to receive(:reconfig_vm) do |reconfig_vm, vm_config|
          expect(reconfig_vm).to eq(vm_mob)
          expect(vm_config.device_change).to eq([nic_config])
        end.ordered

        expect(agent_env).to receive(:set_env).with(
          vm_mob,
          'fake-vm-location',
          {
            'old-key' => 'old-value',
            'networks' => 'fake-network-env'
          }
        ).ordered

        expect(vm).to receive(:power_on).ordered

        vsphere_cloud.configure_networks('vm-id', networks)
      end
    end

    describe '#delete_disk' do
      before { allow(datacenter).to receive(:persistent_datastores).and_return('fake-persistent-datastores') }
      before { allow(datacenter).to receive(:mob).and_return('datacenter-mob') }

      context 'when disk is found' do
        let(:disk) { instance_double('VSphereCloud::Resources::Disk', path: 'disk-path') }
        before do
          allow(disk_provider).to receive(:find).with('fake-disk-uuid').and_return(disk)
        end

        it 'deletes disk' do
          expect(client).to receive(:delete_disk).with('datacenter-mob', 'disk-path')
          vsphere_cloud.delete_disk('fake-disk-uuid')
        end
      end

      context 'when disk is not found' do
        before do
          allow(disk_provider).to receive(:find).
            with('fake-disk-uuid').
            and_raise Bosh::Clouds::DiskNotFound.new(false)
        end

        it 'raises an error' do
          expect {
            vsphere_cloud.delete_disk('fake-disk-uuid')
          }.to raise_error Bosh::Clouds::DiskNotFound
        end
      end
    end

    describe '#create_disk' do
      let(:disk) do
        VSphereCloud::Resources::Disk.new(
          'fake-disk-uuid',
          1024*1024,
          double(:datastore, name: 'fake-datastore'),
          'fake-path'
        )
      end

      it 'creates disk with disk provider' do
        expect(disk_provider).to receive(:create).with(1024, nil).and_return(disk)
        vsphere_cloud.create_disk(1024, {})
      end

      context 'when vm_cid is provided' do
        let(:cluster) { instance_double('VSphereCloud::Resources::Cluster') }
        before do
          allow(vm).to receive(:cluster).and_return('fake-cluster')
          allow(datacenter).to receive(:clusters).and_return({'fake-cluster' => cluster})
        end

        it 'creates disk in vm cluster' do
          allow(vm_provider).to receive(:find).with('fake-vm-cid').and_return(vm)
          expect(disk_provider).to receive(:create).with(1024, cluster).and_return(disk)
          vsphere_cloud.create_disk(1024, {}, 'fake-vm-cid')
        end
      end
    end
  end
end
