require 'spec_helper'

describe VSphereCloud::Resources::Datacenter do
  subject(:datacenter) { described_class.new(config) }

  let(:config) { instance_double('VSphereCloud::Config',
                                 client: client,
                                 datacenter_name: 'fake-datacenter-name',
                                 datacenter_vm_folder: 'fake-vm-folder',
                                 datacenter_template_folder: 'fake-template-folder',
                                 datacenter_clusters: { 'cluster1' => cluster_config1, 'cluster2' => cluster_config2 },
                                 datacenter_disk_path: 'fake-disk-path',
                                 datacenter_datastore_pattern: ephemeral_pattern,
                                 datacenter_persistent_datastore_pattern: persistent_pattern,
                                 datacenter_allow_mixed_datastores: allow_mixed,
  ) }
  let(:client) { instance_double('VSphereCloud::Client') }
  let(:vm_folder) { instance_double('VSphereCloud::Resources::Folder') }
  let(:template_folder) { instance_double('VSphereCloud::Resources::Folder') }
  let(:datacenter_mob) { instance_double('VimSdk::Vim::Datacenter') }
  let(:cluster_mob1) { instance_double('VimSdk::Vim::Cluster') }
  let(:cluster_mob2) { instance_double('VimSdk::Vim::Cluster') }
  let(:cluster_config1) { instance_double('VSphereCloud::ClusterConfig') }
  let(:cluster_config2) { instance_double('VSphereCloud::ClusterConfig') }
  let(:resource_cluster1) { instance_double('VSphereCloud::Resources::Cluster', name: 'cluster1') }
  let(:resource_cluster2) { instance_double('VSphereCloud::Resources::Cluster', name: 'cluster2') }
  let(:ephemeral_pattern) {instance_double('Regexp')}
  let(:persistent_pattern) {instance_double('Regexp')}
  let(:allow_mixed) { false }

  before do
    allow(client).to receive(:find_by_inventory_path).with('fake-datacenter-name').and_return(datacenter_mob)
    allow(VSphereCloud::Resources::Folder).to receive(:new).with(
                                                'fake-vm-folder', config).and_return(vm_folder)
    allow(VSphereCloud::Resources::Folder).to receive(:new).with(
                                                'fake-template-folder', config).and_return(template_folder)
    allow(client).to receive(:get_managed_objects).with(
                       VimSdk::Vim::ClusterComputeResource,
                       root: datacenter_mob, include_name: true).and_return(
                       {
                         'cluster1' => cluster_mob1,
                         'cluster2' => cluster_mob2,
                       }
                     )
    allow(client).to receive(:get_properties).with(
                       [cluster_mob1, cluster_mob2],
                       VimSdk::Vim::ClusterComputeResource,
                       VSphereCloud::Resources::Cluster::PROPERTIES,
                       ensure_all: true).and_return({ cluster_mob1 => {}, cluster_mob2 => {} })

    allow(VSphereCloud::Resources::Cluster).to receive(:new).with(
                                                 config, cluster_config1, {}).and_return(resource_cluster1)
    allow(VSphereCloud::Resources::Cluster).to receive(:new).with(
                                                 config, cluster_config2, {}).and_return(resource_cluster2)
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
    it "returns a folder object using the datacenter's vm folder" do
      expect(datacenter.vm_folder).to eq(vm_folder)
    end
  end

  describe '#template_folder' do
    it "returns a folder object using the datacenter's template folder" do
      expect(datacenter.template_folder).to eq(template_folder)
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

  describe '#allow_mixed' do
    it 'returns the value from the config' do
      expect(datacenter.allow_mixed).to eq(false)
    end

    context 'when allow mixed is true' do
      let(:allow_mixed) { true }
      it 'returns the value from the config' do
        expect(datacenter.allow_mixed).to eq(true)
      end
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
      expect(clusters['cluster1']).to eq(resource_cluster1)
      expect(clusters['cluster2']).to eq(resource_cluster2)
    end

    context 'when a cluster mob cannot be found' do
      it 'raises an exception' do
        allow(client).to receive(:get_managed_objects).with(
                           VimSdk::Vim::ClusterComputeResource,
                           root: datacenter_mob, include_name: true).and_return(
                           {
                             'cluster2' => cluster_mob2,
                           }
                         )

        allow(client).to receive(:get_properties).with(
                           [cluster_mob2],
                           VimSdk::Vim::ClusterComputeResource,
                           VSphereCloud::Resources::Cluster::PROPERTIES,
                           ensure_all: true).and_return({ cluster_mob2 => {} })


        expect { datacenter.clusters }.to raise_error(/Can't find cluster: cluster1/)
      end

    end

    context 'when properties for a cluster cannot be found' do
      it 'raises an exception' do
        allow(client).to receive(:get_properties).with(
                           [cluster_mob1, cluster_mob2],
                           VimSdk::Vim::ClusterComputeResource,
                           VSphereCloud::Resources::Cluster::PROPERTIES,
                           ensure_all: true).and_return({ cluster_mob2 => {} })

        expect { datacenter.clusters }.to raise_error(/Can't find properties for cluster: cluster1/)
      end

    end
  end

  #it "should create a datacenter" do
  #  dc_mob = double(:dc_mob)
  #  cluster_mob = double(:cluster_mob)
  #
  #  @client.should_receive(:find_by_inventory_path).with("TEST_DC").
  #      and_return(dc_mob)
  #  @client.should_receive(:get_managed_objects).
  #      with(VimSdk::Vim::ClusterComputeResource,
  #           {:root=>dc_mob, :include_name=>true}).
  #      and_return({"foo" => cluster_mob})
  #  @client.should_receive(:get_properties).
  #      with([cluster_mob], VimSdk::Vim::ClusterComputeResource,
  #           %w(name datastore resourcePool host), {:ensure_all => true}).
  #      and_return({cluster_mob => {:foo => :bar}})

  #folder_config = VSphereCloud::Config::FolderConfig.new
  #folder_config.vm = "vms"
  #folder_config.template = "templates"
  #folder_config.shared = false
  #cluster_config = VSphereCloud::Config::ClusterConfig.new("foo")
  #datastore_config = VSphereCloud::Config::DatastoreConfig.new
  #datastore_config.disk_path = "bosh_disks"

  #dc_config = double(:dc_config)
  #dc_config.stub(:name).and_return("TEST_DC")
  #dc_config.stub(:folders).and_return(folder_config)
  #dc_config.stub(:clusters).and_return({"foo" => cluster_config})
  #dc_config.stub(:datastores).and_return(datastore_config)

  #vm_folder = double(:vm_folder)
  #VSphereCloud::Resources::Folder.stub(:new).
  #    with(an_instance_of(VSphereCloud::Resources::Datacenter),
  #         "vms", false).
  #    and_return(vm_folder)
  #
  #template_folder = double(:template_folder)
  #VSphereCloud::Resources::Folder.stub(:new).
  #    with(an_instance_of(VSphereCloud::Resources::Datacenter),
  #         "templates", false).
  #    and_return(template_folder)
  #
  #cluster = double(:cluster)
  #cluster.stub(:name).and_return("foo")
  #VSphereCloud::Resources::Cluster.stub(:new).
  #    with(an_instance_of(VSphereCloud::Resources::Datacenter),
  #         cluster_config, {:foo => :bar}).
  #    and_return(cluster)
  #
  #datacenter = VSphereCloud::Resources::Datacenter.new(dc_config)
  #datacenter.mob.should == dc_mob
  #datacenter.clusters.should == {"foo" => cluster}
  #datacenter.vm_folder.should == vm_folder
  #datacenter.template_folder.should == template_folder
  #datacenter.config.should == dc_config
  #datacenter.name.should == "TEST_DC"
  #datacenter.disk_path.should == "bosh_disks"
  #end

  #end
end
