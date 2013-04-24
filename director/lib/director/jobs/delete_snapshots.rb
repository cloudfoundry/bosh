module Bosh::Director
  module Jobs
    class DeleteSnapshot < BaseJob

      @queue = :normal

      def initialize(snapshots)
        @snapshots = snapshots
        @cloud = Config.cloud
      end

      def perform
        Bosh::Director::Api::SnapshotManager.delete_snapshots(@snapshots)
      end
    end
  end
end
