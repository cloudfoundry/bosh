require 'spec_helper'

module VSphereCloud
  describe Resources do
    subject(:resources) { VSphereCloud::Resources.new(datacenter, cluster_locality, config) }
    let(:cluster_locality) { instance_double(VSphereCloud::ClusterLocality) }
    let(:config) { instance_double('VSphereCloud::Config', client: client, logger: logger) }
    let(:client) { instance_double('VSphereCloud::Client') }
    let(:datacenter) { instance_double('VSphereCloud::Resources::Datacenter', name: 'datacenter_name') }
    let(:logger) { instance_double('Logger', info: nil, debug: nil) }

    describe :pick_persistent_datastore_in_cluster do
      let(:cluster) { double(:cluster) }
      before { allow(datacenter).to receive(:clusters).and_return({ "bar" => cluster }) }

      it "should return the datastore when it was placed successfully" do
        datastore = double(:datastore)
        expect(datastore).to receive(:allocate).with(1024)
        expect(cluster).to receive(:pick_persistent).with(1024).and_return(datastore)
        expect(resources.pick_persistent_datastore_in_cluster("bar", 1024)).
          to eq(datastore)
      end

      it "should return nil when it wasn't placed successfully" do
        expect(cluster).to receive(:pick_persistent).with(1024).and_return(nil)
        expect(resources.pick_persistent_datastore_in_cluster("bar", 1024)).
          to be_nil
      end
    end

    describe '#pick_cluster_for_vm' do
      def make_cluster_with_disks(options)
        cluster = instance_double(VSphereCloud::Resources::Cluster, name: 'fake-cluster')
        cluster_with_disks = instance_double(VSphereCloud::Resources::ClusterWithDisks,
          cluster: cluster,
          disks: options[:disks])

        allow(cluster).to receive(:pick_ephemeral).with(1024).and_return(options[:datastore])
        allow(cluster).to receive(:allocate).with(512)

        scorer = instance_double(VSphereCloud::Resources::Scorer)
        allow(scorer).to receive(:score).and_return(options[:score])
        allow(VSphereCloud::Resources::Scorer).to receive(:new).
          with(config, cluster, 512, 1024, options[:disks].map(&:size_in_mb)).and_return(scorer)

        cluster_with_disks
      end

      context 'when there is a cluster that has persistent disks with non-0 score' do
        it 'chooses the cluster with the largest disk size and score > 0' do
          disk_a = instance_double(VSphereCloud::Resources::Disk, size_in_mb: 1024)
          disk_b = instance_double(VSphereCloud::Resources::Disk, size_in_mb: 1024)
          disks = [disk_a, disk_b]

          cluster_with_more_disks_but_not_enough_space = make_cluster_with_disks(
            disks: [disk_a],
            score: 0,
            datastore: instance_double(VSphereCloud::Resources::Datastore)
          )

          datastore = instance_double(VSphereCloud::Resources::Datastore)
          cluster_with_fewer_disks_but_enough_space = make_cluster_with_disks(
            disks: [disk_b],
            score: 4,
            datastore: datastore
          )

          allow(cluster_locality).to receive(:clusters_ordered_by_disk_size).with(disks).
            and_return([cluster_with_more_disks_but_not_enough_space, cluster_with_fewer_disks_but_enough_space])

          expect(cluster_with_fewer_disks_but_enough_space.cluster).to receive(:allocate).with(512)
          expect(resources.pick_cluster_for_vm(512, 1024, disks)).to eq(cluster_with_fewer_disks_but_enough_space.cluster)
        end
      end

      context 'when there are no clusters with non-0 score that have disks' do
        it 'chooses the random cluster weighted by score' do
          cluster_without_disks_with_disks = make_cluster_with_disks(
            disks: [],
            score: 1,
            datastore: instance_double(VSphereCloud::Resources::Datastore)
          )

          datastore = instance_double(VSphereCloud::Resources::Datastore)
          cluster_without_disks_with_bigger_score_with_disks = make_cluster_with_disks(
            disks: [],
            score: 4,
            datastore: datastore
          )

          allow(cluster_locality).to receive(:clusters_ordered_by_disk_size).with([]).
            and_return([cluster_without_disks_with_disks, cluster_without_disks_with_bigger_score_with_disks])

          allow(Resources::Util).to receive(:weighted_random).
            with([[cluster_without_disks_with_disks, 1], [cluster_without_disks_with_bigger_score_with_disks, 4]]).
            and_return( cluster_without_disks_with_bigger_score_with_disks)

          expect(cluster_without_disks_with_bigger_score_with_disks.cluster).to receive(:allocate).with(512)

          expect(resources.pick_cluster_for_vm(512, 1024, [])).to eq(cluster_without_disks_with_bigger_score_with_disks.cluster)
        end
      end

      context 'when all clusters score as 0' do
        it 'raises an error' do
          cluster_a = make_cluster_with_disks(
            disks: [],
            score: 0,
            datastore: instance_double(VSphereCloud::Resources::Datastore)
          )

          cluster_b = make_cluster_with_disks(
            disks: [],
            score: 0,
            datastore: instance_double(VSphereCloud::Resources::Datastore)
          )

          allow(cluster_locality).to receive(:clusters_ordered_by_disk_size).with([]).
            and_return([cluster_a, cluster_b])

          expect {
            resources.pick_cluster_for_vm(512, 1024, [])
          }.to raise_error /No available resources/
        end
      end
    end

    describe 'pick_ephemeral_datastore' do
      let(:cluster) { instance_double(VSphereCloud::Resources::Cluster, name: 'awesome cluster') }
      let(:datastore) { instance_double(VSphereCloud::Resources::Datastore, allocate: nil) }

      before { allow(cluster).to receive(:pick_ephemeral).with(1024).and_return(datastore) }

      it 'picks ephemeral datastore in cluster' do
        expect(resources.pick_ephemeral_datastore(cluster, 1024)).to eq(datastore)
      end

      it 'allocates disk size in datastore' do
        resources.pick_ephemeral_datastore(cluster, 1024)
        expect(datastore).to have_received(:allocate).with(1024)
      end

      context 'when cluster does not have datastore to satisfy disk size requirement' do
        before { allow(cluster).to receive(:pick_ephemeral).with(1024).and_return(nil) }
        it 'raises Bosh::Clouds::NoDiskSpace' do
          expect {
            resources.pick_ephemeral_datastore(cluster, 1024)
          }.to raise_error Bosh::Clouds::NoDiskSpace
        end
      end
    end

    describe 'pick_persistent_datastore' do
      let(:cluster) { instance_double(VSphereCloud::Resources::Cluster, name: 'awesome cluster') }
      let(:datastore) { instance_double(VSphereCloud::Resources::Datastore, allocate: nil) }

      before { allow(cluster).to receive(:pick_persistent).with(1024).and_return(datastore) }

      it 'picks persistent datastore in cluster' do
        expect(resources.pick_persistent_datastore(cluster, 1024)).to eq(datastore)
      end

      it 'allocates disk size in datastore' do
        resources.pick_persistent_datastore(cluster, 1024)
        expect(datastore).to have_received(:allocate).with(1024)
      end

      context 'when cluster does not have datastore to satisfy disk size requirement' do
        before { allow(cluster).to receive(:pick_persistent).with(1024).and_return(nil) }
        it 'raises Bosh::Clouds::NoDiskSpace' do
          expect {
            resources.pick_persistent_datastore(cluster, 1024)
          }.to raise_error Bosh::Clouds::NoDiskSpace
        end
      end
    end
  end
end
