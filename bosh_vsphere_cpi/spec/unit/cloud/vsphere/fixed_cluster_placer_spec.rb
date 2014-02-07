require 'cloud/vsphere/fixed_cluster_placer'

module VSphereCloud
  describe FixedClusterPlacer do
    describe "#place" do
      subject(:fixed_cluster_placer) { described_class.new(cluster) }
      let(:memory) { 2 * 1024 }
      let(:ephemeral) { 2 * 1024 * 1024 }
      let(:persistent) { Hash.new }
      let(:cluster) { double(:cluster) }
      let(:datastore) { double(:datastore) }

      context "when the VM fits into the specified cluster" do
        before {
          allow(cluster).to receive(:pick_ephemeral).with(ephemeral).and_return(datastore)
          allow(cluster).to receive(:allocate).with(memory)
          allow(datastore).to receive(:allocate).with(ephemeral)
        }

        it "returns the cluster that was passed in" do
          expect(cluster).to receive(:allocate).with(memory)
          expect(fixed_cluster_placer.place(memory, ephemeral, persistent)[0]).to eq(cluster)
        end

        it "returns the selected datastore" do
          expect(datastore).to receive(:allocate).with(ephemeral)
          expect(fixed_cluster_placer.place(memory, ephemeral, persistent)[1]).to eq(datastore)
        end
      end

      context "when the VM does not fit into the specified cluster" do
        it "raises 'No available resources'" do
          allow(cluster).to receive(:pick_ephemeral).and_return(nil)

          expect { fixed_cluster_placer.place(memory, ephemeral, persistent) }.to raise_error RuntimeError,
                                                                                            "No available resources"
        end
      end
    end
  end
end
