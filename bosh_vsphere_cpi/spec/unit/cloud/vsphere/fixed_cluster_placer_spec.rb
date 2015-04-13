require 'spec_helper'

module VSphereCloud
  describe FixedClusterPlacer do
    let(:cluster) { instance_double(VSphereCloud::Resources::Cluster, name: 'awesome cluster', allocate: nil) }
    let(:datastore) { instance_double(VSphereCloud::Resources::Datastore, allocate: nil) }
    let(:drs_rules) { [] }


    subject(:fixed_cluster_placer) { described_class.new(cluster, drs_rules) }

    describe "#pick_cluster_for_vm" do
      it "returns the fixed cluster" do
        expect(fixed_cluster_placer.pick_cluster_for_vm(128, 256, [])).to eq(cluster)
      end

      it "allocates the memory" do
        fixed_cluster_placer.pick_cluster_for_vm(128, 256, [])
        expect(cluster).to have_received(:allocate).with(128)
      end
    end

    describe "#pick_ephemeral_datastore" do
      before { allow(cluster).to receive(:pick_ephemeral).with(128).and_return(datastore) }

      it "returns the ephemeral datastore" do
        expect(fixed_cluster_placer.pick_ephemeral_datastore(cluster, 128)).to eq(datastore)
      end

      it "allocates the disk space" do
        fixed_cluster_placer.pick_ephemeral_datastore(cluster, 128)
        expect(datastore).to have_received(:allocate).with(128)
      end
    end

    describe "#pick_persistent_datastore" do
      it "raises if there isn't enough space" do
        expect {
          fixed_cluster_placer.pick_persistent_datastore(cluster, 128)
        }.to raise_error NotImplementedError
      end
    end
  end
end
