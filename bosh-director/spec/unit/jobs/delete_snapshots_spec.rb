require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteSnapshots do
    let(:snapshots) { [Models::Snapshot.make(snapshot_cid: 'snap0'), Models::Snapshot.make(snapshot_cid: 'snap1')] }

    subject(:job) { described_class.new(%w(snap0 snap1)) }

    describe 'Resque job class expectations' do
      let(:job_type) { :delete_snapshot }
      it_behaves_like 'a Resque job'
    end

    it 'tells the snapshot manager to delete the snapshots' do
      expect(Api::SnapshotManager).to receive(:delete_snapshots).with(snapshots)

      expect(job.perform).to eq 'snapshot(s) snap0, snap1 deleted'
    end
  end
end
