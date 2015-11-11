module Bosh::Director
  module Jobs
    class ScheduledOrphanCleanup < BaseJob
      @queue = :normal

      def self.job_type
        :scheduled_orphan_cleanup
      end

      def self.schedule_message
        "clean up orphan disks"
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

        old_orphans = Models::OrphanDisk.where('created_at < ?', time)
        stage = event_log.begin_stage('Deleting orphan disks', old_orphans.count)
        old_orphans.each do |old_orphan|
          stage.advance_and_track("#{old_orphan.disk_cid}") do
            @disk_manager.delete_orphan_disk(old_orphan)
          end
        end
        "Deleted #{old_orphans.count} orphaned disk(s) older than #{time}"
      rescue => e
        logger.error("Error occurred cleaning up orphaned disks and orphaned snapshots: #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end
  end
end
