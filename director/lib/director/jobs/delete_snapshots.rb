module Bosh::Director
  module Jobs
    class DeleteSnapshots < BaseJob

      @queue = :normal

      def initialize(snapshots_cids)
        @snapshot_cids = snapshots_cids
      end

      def perform
        snapshots = @snapshot_cids.collect { |cid| Bosh::Director::Models::Snapshot.find(snapshot_cid: cid) }
        Bosh::Director::Api::SnapshotManager.delete_snapshots(snapshots)
        "snapshot(s) #{@snapshot_cids.join(', ')} deleted"
      end
    end
  end
end
