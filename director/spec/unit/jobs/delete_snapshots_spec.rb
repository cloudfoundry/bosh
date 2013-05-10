require 'spec_helper'

describe Bosh::Director::Jobs::DeleteSnapshots do
  let(:snapshots) { [BDM::Snapshot.make(snapshot_cid: "snap0"), BDM::Snapshot.make(snapshot_cid: "snap1")] }

  subject(:job) { described_class.new(%w(snap0 snap1)) }

  it 'tells the snapshot manager to delete the snapshots' do
    BD::Api::SnapshotManager.should_receive(:delete_snapshots).with(snapshots)

    expect(job.perform).to eq 'snapshot(s) snap0, snap1 deleted'
  end

end
