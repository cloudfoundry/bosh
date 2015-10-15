module Bosh::Director
  module Jobs
    class DeleteSnapshots < BaseJob

      @queue = :normal

      def self.job_type
        :delete_snapshot
      end

      def initialize(snapshots_cids)
        @snapshot_cids = snapshots_cids
      end

      def perform
        logger.info("deleting snapshots: #{@snapshot_cids.join(', ')}")
        snapshots = Bosh::Director::Models::Snapshot.where(snapshot_cid: @snapshot_cids).to_a
        Bosh::Director::Api::SnapshotManager.delete_snapshots(snapshots)
        "snapshot(s) #{@snapshot_cids.join(', ')} deleted"
      end
    end
  end
end
