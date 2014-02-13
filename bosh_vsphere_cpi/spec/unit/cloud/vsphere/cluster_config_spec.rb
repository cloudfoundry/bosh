require 'spec_helper'

require 'cloud/vsphere/cluster_config'

module VSphereCloud
  describe ClusterConfig do
    subject(:cluster_config) { described_class.new(name, config) }
    let(:name) { 'fake-cluster-name' }
    let(:config) { { 'resource_pool' => 'fake-resource-pool' } }

    describe '#name' do
      it 'returns the cluster name' do
        expect(cluster_config.name).to eq(name)
      end
    end

    describe '#resource_pool' do
      it 'returns the resource pool name' do
        expect(cluster_config.resource_pool).to eq('fake-resource-pool')
      end
    end
  end
end
