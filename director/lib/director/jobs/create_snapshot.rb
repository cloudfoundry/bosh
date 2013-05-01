module Bosh::Director
  module Jobs
    class CreateSnapshot < BaseJob

      @queue = :normal

      def initialize(instance_id, options)
        @instance = Bosh::Director::Api::InstanceManager.new.find_instance(instance_id)
        @options = options
      end

      def perform
        snapshot_cids = Bosh::Director::Api::SnapshotManager.take_snapshot(@instance, @options)
        "snapshot(s) #{snapshot_cids.join(', ')} created"
      end
    end
  end
end
