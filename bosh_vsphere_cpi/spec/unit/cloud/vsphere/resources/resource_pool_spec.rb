require 'spec_helper'

describe VSphereCloud::Resources::ResourcePool do
  subject { VSphereCloud::Resources::ResourcePool.new(cloud_config, cluster_config, root_resource_pool_mob) }
  let(:cloud_config) { instance_double('VSphereCloud::Config', logger: fake_logger, client: fake_client) }
  let(:fake_logger) { instance_double('Logger', debug: nil) }
  let(:fake_client) { instance_double('VSphereCloud::Client') }
  let(:cluster_config) do
    instance_double('VSphereCloud::ClusterConfig', name: 'fake-cluster-name', resource_pool: cluster_resource_pool)
  end
  let(:cluster_resource_pool) { nil }
  let(:root_resource_pool_mob) { instance_double('VimSdk::Vim::ResourcePool') }

  describe '#initialize' do

    context 'when the cluster config does not provide a resource pool' do
      it 'uses the root resource pool' do
        expect(subject.mob).to eq(root_resource_pool_mob)
      end
    end

    context 'when the cluster config provides a resource pool' do
      let(:cluster_resource_pool) { 'cluster-resource-pool' }
      it 'uses the cluster config resource pool' do
        resource_pool_mob = instance_double('VimSdk::Vim::ResourcePool')

        allow(fake_client).to receive(:get_managed_object)
                              .with(VimSdk::Vim::ResourcePool, root: root_resource_pool_mob, name: cluster_resource_pool)
                              .and_return(resource_pool_mob)

        expect(subject.mob).to eq(resource_pool_mob)
      end
    end
  end

  describe '#inspect' do
    it 'returns the printable form' do
      expect(subject.inspect).to eq("<Resource Pool: #{root_resource_pool_mob}>")
    end
  end
end
