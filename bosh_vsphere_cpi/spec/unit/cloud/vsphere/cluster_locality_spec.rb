require 'spec_helper'

module VSphereCloud
  describe ClusterLocality do
    subject(:locality) { described_class.new(clusters) }
    let(:cluster_a) { FakeCluster.new('cluster_a', [datastore_a]) }
    let(:cluster_b) { FakeCluster.new('cluster_b', [datastore_b]) }
    let(:cluster_c) { FakeCluster.new('cluster_c', [datastore_a, datastore_c]) }
    let(:clusters) { [cluster_a, cluster_b, cluster_c] }

    let(:disk_a) { instance_double(Resources::Disk, size_in_mb: 1200, datastore: datastore_a) }
    let(:disk_b) { instance_double(Resources::Disk, size_in_mb: 1024, datastore: datastore_b) }
    let(:disk_c) { instance_double(Resources::Disk, size_in_mb: 1024, datastore: datastore_c) }
    let(:disks) { [disk_a, disk_b, disk_c] }

    let(:datastore_a) { instance_double(Resources::Datastore, name: 'datastore_a') }
    let(:datastore_b) { instance_double(Resources::Datastore, name: 'datastore_b') }
    let(:datastore_c) { instance_double(Resources::Datastore, name: 'datastore_c') }

    describe 'clusters_ordered_by_disk_size' do
      it 'returns clusters in order of their disk sizes' do
        expect(locality.clusters_ordered_by_disk_size(disks).map(&:cluster)).to eq([
          cluster_c,
          cluster_a,
          cluster_b
        ])
      end
    end
  end
end
