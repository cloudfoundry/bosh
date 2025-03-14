require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteSnapshots do
    let(:snapshots) { [FactoryBot.create(:models_snapshot, snapshot_cid: 'snap0'), FactoryBot.create(:models_snapshot, snapshot_cid: 'snap1')] }

    subject(:job) { described_class.new(%w(snap0 snap1)) }

    describe 'DJ job class expectations' do
      let(:job_type) { :delete_snapshot }
      let(:queue) { :normal }
      it_behaves_like 'a DelayedJob job'
    end

    it 'tells the snapshot manager to delete the snapshots' do
      expect(Api::SnapshotManager).to receive(:delete_snapshots).with(snapshots)

      expect(job.perform).to eq 'snapshot(s) snap0, snap1 deleted'
    end
  end
end
