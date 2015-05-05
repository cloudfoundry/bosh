require 'spec_helper'

describe VSphereCloud::Resources::Datacenter do
  subject(:datacenter) {
    described_class.new({
      client: client,
      name: datacenter_name,
      vm_folder: 'fake-vm-folder',
      template_folder: 'fake-template-folder',
      clusters: {'cluster1' => cluster_config1, 'cluster2' => cluster_config2},
      disk_path: 'fake-disk-path',
      ephemeral_pattern: ephemeral_pattern,
      persistent_pattern: persistent_pattern,
      use_sub_folder: datacenter_use_sub_folder,
      logger: logger,
      mem_overcommit: 0.5,
    })
  }
  let(:log_output) { StringIO.new("") }
  let(:logger) { Logger.new(log_output) }
  let(:client) { instance_double('VSphereCloud::Client') }

  let(:vm_folder) { instance_double('VSphereCloud::Resources::Folder') }
  let(:vm_subfolder) { instance_double('VSphereCloud::Resources::Folder') }

  let(:datacenter_use_sub_folder) { false }

  let(:template_folder) { instance_double('VSphereCloud::Resources::Folder') }
  let(:template_subfolder) { instance_double('VSphereCloud::Resources::Folder') }
  let(:datacenter_mob) { instance_double('VimSdk::Vim::Datacenter') }
  let(:cluster_mob1) { instance_double('VimSdk::Vim::Cluster') }
  let(:cluster_mob2) { instance_double('VimSdk::Vim::Cluster') }
  let(:cluster_config1) { instance_double('VSphereCloud::ClusterConfig', resource_pool: nil, name: 'cluster1') }
  let(:cluster_config2) { instance_double('VSphereCloud::ClusterConfig', resource_pool: nil, name: 'cluster2') }
  let(:ephemeral_pattern) {instance_double('Regexp')}
  let(:persistent_pattern) {instance_double('Regexp')}
  let(:cloud_searcher) { instance_double('VSphereCloud::CloudSearcher') }
  let(:datastore_properties) { {} }

  let(:datacenter_name) { 'fake-datacenter-name' }
  before do
    allow(client).to receive(:find_by_inventory_path).with(datacenter_name).and_return(datacenter_mob)
    allow(client).to receive(:cloud_searcher).and_return(cloud_searcher)

    allow(VSphereCloud::Resources::Folder).to receive(:new).with(
      'fake-vm-folder', logger, client, datacenter_name
    ).and_return(vm_folder)

    allow(VSphereCloud::Resources::Folder).to receive(:new).with(
      'fake-vm-folder/fake-uuid', logger, client, datacenter_name
    ).and_return(vm_subfolder)

    allow(VSphereCloud::Resources::Folder).to receive(:new).with(
      'fake-template-folder', logger, client, datacenter_name
    ).and_return(template_folder)

    allow(VSphereCloud::Resources::Folder).to receive(:new).with(
      'fake-template-folder/fake-uuid', logger, client, datacenter_name
    ).and_return(template_subfolder)

    allow(cloud_searcher).to receive(:get_managed_objects).with(
      VimSdk::Vim::ClusterComputeResource,
      root: datacenter_mob, include_name: true
    ).and_return(
      [
        ['cluster1', cluster_mob1],
        ['cluster2', cluster_mob2],
      ]
    )

    allow(cloud_searcher).to receive(:get_properties).with(
      cluster_mob1,
      VimSdk::Vim::ClusterComputeResource,
      VSphereCloud::Resources::Cluster::PROPERTIES,
      ensure_all: true
    ).and_return({ cluster_mob1 => {} })
    allow(cloud_searcher).to receive(:get_properties).with(
        cluster_mob2,
        VimSdk::Vim::ClusterComputeResource,
        VSphereCloud::Resources::Cluster::PROPERTIES,
        ensure_all: true
      ).and_return({ cluster_mob2 => {} })

    allow(cloud_searcher).to receive(:get_properties).with(
      nil, VimSdk::Vim::Datastore, VSphereCloud::Resources::Datastore::PROPERTIES
    ).and_return(datastore_properties)
    allow(Bosh::Clouds::Config).to receive(:uuid).and_return('fake-uuid')
  end

  describe '#mob' do
    context 'when mob is found' do
      it 'returns the datacenter mob' do
        expect(datacenter.mob).to eq(datacenter_mob)
      end
    end
    context 'when mob is not found' do
      before { allow(client).to receive(:find_by_inventory_path).with('fake-datacenter-name').and_return(nil) }
      it 'raises' do
        expect { datacenter.mob }.to raise_error(RuntimeError, 'Datacenter: fake-datacenter-name not found')
      end

    end
  end

  describe '#vm_folder' do
    context 'when datacenter does not use subfolders' do
      let(:datacenter_use_sub_folder) { false }

      it "returns a folder object using the datacenter's vm folder" do
        expect(datacenter.vm_folder).to eq(vm_folder)
      end
    end

    context 'when datacenter uses subfolders' do
      let(:datacenter_use_sub_folder) { true }

      it 'returns multi-tenant folder' do
        expect(datacenter.vm_folder).to eq(vm_subfolder)
      end
    end
  end

  describe '#master_vm_folder' do
    it "returns a folder object using the datacenter's vm folder" do
      expect(datacenter.master_vm_folder).to eq(vm_folder)
    end
  end

  describe '#template_folder' do
    context 'when datacenter does not use subfolders' do
      let(:datacenter_use_sub_folder) { false }

      it "returns a folder object using the datacenter's vm folder" do
        expect(datacenter.template_folder).to eq(template_folder)
      end
    end

    context 'when datacenter uses subfolders' do
      let(:datacenter_use_sub_folder) { true }

      it 'returns subfolder' do
        expect(datacenter.template_folder).to eq(template_subfolder)
      end
    end
  end

  describe '#master_template_folder' do
    it "returns a folder object using the datacenter's template folder" do
      expect(datacenter.master_template_folder).to eq(template_folder)
    end
  end

  describe '#name' do
    it 'returns the datacenter name' do
      expect(datacenter.name).to eq('fake-datacenter-name')
    end
  end

  describe '#disk_path' do
    it ' returns the datastore disk path' do
      expect(datacenter.disk_path).to eq('fake-disk-path')
    end
  end

  describe '#ephemeral_pattern' do
    it 'returns a Regexp object defined by the configuration' do
      expect(datacenter.ephemeral_pattern).to eq(ephemeral_pattern)
    end
  end

  describe '#persistent_pattern' do
    it 'returns a Regexp object defined by the configuration' do
      expect(datacenter.persistent_pattern).to eq(persistent_pattern)
    end
  end

  describe '#inspect' do
    it 'includes the mob and the name of the datacenter' do
      expect(datacenter.inspect).to eq("<Datacenter: #{datacenter_mob} / fake-datacenter-name>")
    end
  end

  describe '#clusters' do
    it 'returns a hash mapping from cluster name to a configured cluster object' do
      clusters = datacenter.clusters
      expect(clusters.keys).to match_array(['cluster1', 'cluster2'])
      expect(clusters['cluster1'].name).to eq('cluster1')
      expect(clusters['cluster1'].datacenter).to eq(datacenter)
      expect(clusters['cluster2'].name).to eq('cluster2')
      expect(clusters['cluster2'].datacenter).to eq(datacenter)
    end

    context 'when a cluster mob cannot be found' do
      it 'raises an exception' do
        allow(cloud_searcher).to receive(:get_managed_objects).with(
                           VimSdk::Vim::ClusterComputeResource,
                           root: datacenter_mob, include_name: true).and_return(
                           {
                             'cluster2' => cluster_mob2,
                           }
                         )

        allow(cloud_searcher).to receive(:get_properties).with(
                           [cluster_mob2],
                           VimSdk::Vim::ClusterComputeResource,
                           VSphereCloud::Resources::Cluster::PROPERTIES,
                           ensure_all: true).and_return({ cluster_mob2 => {} })


        expect { datacenter.clusters }.to raise_error(/Can't find cluster: cluster1/)
      end
    end
  end

  describe '#persistent_datastores' do
    let(:first_datastore) { instance_double('VSphereCloud::Resources::Datastore', name: 'first-datastore') }
    let(:second_datastore) { instance_double('VSphereCloud::Resources::Datastore', name: 'second-datastore') }

    before do
      allow(datacenter).to receive(:clusters).and_return({
       'first-cluster' => instance_double('VSphereCloud::Resources::Cluster',
         persistent_datastores: {'first-datastore' => first_datastore},
       ),
       'second-cluster' => instance_double('VSphereCloud::Resources::Cluster',
         persistent_datastores: {
           'first-datastore' => first_datastore,
           'second-datastore' => second_datastore
         }
       ),
      })
    end

    it 'returns persistent datastores in all clusters' do
      expect(datacenter.persistent_datastores).to eq({
        'first-datastore' => first_datastore,
        'second-datastore' => second_datastore
      })
    end
  end

  describe '#vm_path' do
    it 'builds the vm path' do
      allow(vm_folder).to receive(:path_components) { ['vm-folder', 'path-components'] }
      expect(datacenter.vm_path('fake-vm-cid')).to eq('fake-datacenter-name/vm/vm-folder/path-components/fake-vm-cid')
    end
  end

  describe '#pick_persistent_datastore' do
    let(:persistent_pattern) { /ds/ }
    let(:datastore_properties) do
      bytes_in_mb = VSphereCloud::Resources::BYTES_IN_MB
      disk_threshold = VSphereCloud::Resources::DISK_HEADROOM
      {
        'ds1' => { 'name' => 'ds1', 'summary.freeSpace' => (1024 + disk_threshold) * bytes_in_mb, 'summary.capacity' => 20000 * bytes_in_mb },
        'ds2' => { 'name' => 'ds2', 'summary.freeSpace' => (2048 + disk_threshold) * bytes_in_mb, 'summary.capacity' => 20000 * bytes_in_mb  },
        'ds32' => { 'name' => 'ds3', 'summary.freeSpace' => (512 + disk_threshold) * bytes_in_mb, 'summary.capacity' => 20000 * bytes_in_mb  },
      }
    end

    it 'returns datastore with weighted random from datastores with enough space' do
      first_datastore = nil
      expect(VSphereCloud::Resources::Util).to receive(:weighted_random) do |weighted_datastores|
        expect(weighted_datastores.size).to eq(2)
        first_datastore, first_weight = weighted_datastores.first
        expect(first_datastore.name).to eq('ds1')
        expect(first_weight).to eq(1024 + VSphereCloud::Resources::DISK_HEADROOM)

        second_datastore, second_weight = weighted_datastores[1]
        expect(second_datastore.name).to eq('ds2')
        expect(second_weight).to eq(2048 + VSphereCloud::Resources::DISK_HEADROOM)

        first_datastore
      end
      expect(datacenter.pick_persistent_datastore(1024)).to eq(first_datastore)
    end

    it 'logs a bunch of debug info since it is really hard to know what happening otherwise' do
      datacenter.pick_persistent_datastore(1024)

      expect(log_output.string).to include 'Looking for a persistent datastore with 1024MB free space.'
      expect(log_output.string).to include 'All datastores: ["ds1 (2048MB free of 20000MB capacity)", "ds2 (3072MB free of 20000MB capacity)", "ds3 (1536MB free of 20000MB capacity)"]'
      expect(log_output.string).to include 'Datastores with enough space: ["ds1 (2048MB free of 20000MB capacity)", "ds2 (3072MB free of 20000MB capacity)"]'
    end

    context 'and there is less persistent free space than the disk threshold' do
      it 'raises a Bosh::Clouds::NoDiskSpace' do
        expect {
          datacenter.pick_persistent_datastore(10000)
        }.to raise_error do |error|
          expect(error).to be_an_instance_of(Bosh::Clouds::NoDiskSpace)
          expect(error.ok_to_retry).to be(true)
          expect(error.message).to eq(<<-MSG)
Couldn't find a persistent datastore with 10000MB of free space. Found:
 ds1 (2048MB free of 20000MB capacity)
 ds2 (3072MB free of 20000MB capacity)
 ds3 (1536MB free of 20000MB capacity)
          MSG
        end
      end
    end
  end
end
