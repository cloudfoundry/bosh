module Bosh::Director
  module Jobs
    class DeleteSnapshots < BaseJob

      @queue = :normal

      def initialize(snapshots)
        @snapshots = snapshots
      end

      def perform
        Bosh::Director::Api::SnapshotManager.delete_snapshots(@snapshots)
      end
    end
  end
end
