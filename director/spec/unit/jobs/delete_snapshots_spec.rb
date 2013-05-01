require 'spec_helper'

describe Bosh::Director::Jobs::DeleteSnapshots do

  let(:snap0) { double(Bosh::Director::Models::Snapshot) }
  let(:snap1) { double(Bosh::Director::Models::Snapshot) }
  let(:snapshots) { [snap0, snap1] }
  let(:snapshot_cids) { %w[snap0 snap1] }

  subject(:job) { described_class.new(snapshot_cids) }

  it 'tells the snapshot manager to delete the snapshots' do
    Bosh::Director::Models::Snapshot.should_receive(:find).with(snapshot_cid: 'snap0').and_return(snap0)
    Bosh::Director::Models::Snapshot.should_receive(:find).with(snapshot_cid: 'snap1').and_return(snap1)
    BD::Api::SnapshotManager.should_receive(:delete_snapshots).with(snapshots)

    expect(job.perform).to eq 'snapshot(s) snap0, snap1 deleted'
  end

end
