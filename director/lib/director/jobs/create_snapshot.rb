module Bosh::Director
  module Jobs
    class CreateSnapshot < BaseJob

      @queue = :normal

      def self.job_type
        :create_snapshot
      end

      def initialize(instance_id, options)
        @instance = Bosh::Director::Api::InstanceManager.new.find_instance(instance_id)
        @options = options
      end

      def perform
        logger.info("taking snapshot of: #{@instance.job}/#{@instance.index} (#{@instance.vm.cid})")
        # TODO ask the agent if the job is running - however, since monit can't distinguish
        # between stopped and not running (failing, etc), we can't do that :(
        snapshot_cids = Bosh::Director::Api::SnapshotManager.take_snapshot(@instance, @options)
        "snapshot(s) #{snapshot_cids.join(', ')} created"
      end
    end
  end
end
