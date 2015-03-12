require 'spec_helper'

describe VSphereCloud::Resources::ResourcePool do
  subject { VSphereCloud::Resources::ResourcePool.new(fake_client, fake_logger, cluster_config, root_resource_pool_mob) }
  let(:fake_logger) { instance_double('Logger', debug: nil) }
  let(:fake_client) { instance_double('VSphereCloud::Client', cloud_searcher: cloud_searcher) }
  let(:cloud_searcher) { instance_double('VSphereCloud::CloudSearcher') }
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

        allow(cloud_searcher).to receive(:get_managed_object)
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
