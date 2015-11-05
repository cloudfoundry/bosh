module Bosh::Director
  module Jobs
    class ScheduledOrphanCleanup < BaseJob
      @queue = :normal

      def self.job_type
        :scheduled_orphan_cleanup
      end

      def initialize(options = {})
        logger.debug("ScheduledOrphanCleanup initialized with options: #{options.inspect}")
        @max_orphaned_age_in_days = options['max_orphaned_age_in_days']
        cloud = options.fetch(:cloud) { Config.cloud }
        @disk_manager = DiskManager.new(cloud, logger)
      end

      def perform
        time = Time.now - (@max_orphaned_age_in_days * 24 * 60 * 60)
        logger.info("Started cleanup of orphan disks and orphan snapshots older than #{time}")
        @disk_manager.delete_orphan_disks_older_than(time)
        "Cleaned up orphaned disks and orphaned snapshots older than #{time}"
      rescue => e
        logger.error("Error occurred cleaning up orphaned disks and orphaned snapshots: #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end
  end
end
