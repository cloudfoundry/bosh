require 'spec_helper'

describe Bosh::Director::Jobs::DeleteSnapshots do
  let(:snapshots) { [BDM::Snapshot.make(snapshot_cid: "snap0"), BDM::Snapshot.make(snapshot_cid: "snap1")] }

  subject(:job) { described_class.new(%w(snap0 snap1)) }

  describe 'described_class.job_type' do
    it 'returns a symbol representing job type' do
      expect(described_class.job_type).to eq(:delete_snapshot)
    end
  end

  it 'tells the snapshot manager to delete the snapshots' do
    BD::Api::SnapshotManager.should_receive(:delete_snapshots).with(snapshots)

    expect(job.perform).to eq 'snapshot(s) snap0, snap1 deleted'
  end
end
