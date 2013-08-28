require 'spec_helper'
require 'cloud/vsphere/vm_creator'

module VSphereCloud
  describe VMCreator do
    let(:logger) { double('Logger', info: nil) }
    let(:agent_id) { '007' }
    let(:stemcell) { 'sc-id' }
    let(:resource_pool) { { 'ram' => 2048, 'disk' => 2048, 'cpu' => 1 } }
    let(:networks) { {} }
    let(:disk_locality) { nil }
    let(:environment) { nil }
    let(:create_disk_config_spec) { double('Disk config', device: nil) }
    let(:agent_env) { { 'env' => {} } }

    let(:vsphere_cloud) do
      instance_double('VSphereCloud::Cloud',
                      replicate_stemcell: stemcell_vm,
                      create_disk_config_spec: create_disk_config_spec,
                      fix_device_unit_numbers: nil,
                      clone_vm: nil,
                      upload_file: nil,
                      configure_env_cdrom: nil,
                      generate_network_env: nil,
                      generate_disk_env: nil,
                      generate_agent_env: agent_env,
                      get_vm_location: nil,
                      set_agent_env: nil,
      )
    end

    let(:template_folder) { instance_double('VSphereCloud::Resources::Folder', name: 'template-folder', mob: nil) }
    let(:vm_folder) { instance_double('VSphereCloud::Resources::Folder', name: 'vm-folder', mob: nil) }

    let(:datacenter) do
      instance_double('VSphereCloud::Resources::Datacenter',
                      name: 'dc',
                      template_folder: template_folder,
                      vm_folder: vm_folder,
                      mob: 'mob',
      )
    end

    let(:resource_pool_resource) { instance_double('VSphereCloud::Resources::ResourcePool', mob: nil) }

    let(:cluster) do
      instance_double('VSphereCloud::Resources::Cluster',
                      mob: nil,
                      datacenter: datacenter,
                      resource_pool: resource_pool_resource,
      )
    end

    let(:resources) do
      instance_double('VSphereCloud::Resources',
                      datacenters: double('Datacenters', values: [datacenter]),
                      place: [cluster, datastore],
      )
    end
    let(:datastore) { instance_double('VSphereCloud::Resources::Datastore', mob: nil, name: 'ds') }
    let(:stemcell_vm) { double('Stemcell VM') }
    let(:client) { instance_double('VSphereCloud::Client') }



    subject(:vm_creator) do
      VMCreator.new(agent_id: agent_id,
                    stemcell: stemcell,
                    resource_pool: resource_pool,
                    networks: networks,
                    disk_locality: disk_locality,
                    environment: environment,
                    resources: resources,
                    client: client,
                    logger: logger,
                    vsphere_cloud: vsphere_cloud,
      )
    end

    before do
      client.stub(get_properties: {
        'config.hardware.device' => [VMCreator::Vim::Vm::Device::VirtualDisk.new],
        'snapshot' => double('Snapshot', current_snapshot: nil)
      })

      client.stub(:get_property).with(stemcell_vm, VMCreator::Vim::VirtualMachine, 'summary.storage.committed', ensure_all: true).and_return(2*1024*1024)
      client.stub(find_by_inventory_path: stemcell_vm)
      client.stub(:wait_for_task)
      client.stub(:reconfig_vm)
      client.stub(:power_on_vm)

      SecureRandom.stub(uuid: 'a-unique-id')
    end

    it 'returns a vm' do
      expect(subject.perform).to eq 'vm-a-unique-id'
    end

    context 'when vm was cloned but an error occurs during additional setup' do
      it 'deletes the created vm' do
        client.stub(:power_on_vm).and_raise('ERROR!!!')
        vsphere_cloud.should_receive(:delete_vm).with('vm-a-unique-id')

        expect {
          subject.perform
        }.to raise_error('ERROR!!!')
      end
    end
  end
end