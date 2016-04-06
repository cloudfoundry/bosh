module Bosh::Director
  module Jobs
    class ScheduledOrphanCleanup < BaseJob
      @queue = :normal

      def self.job_type
        :scheduled_orphan_cleanup
      end

      def self.has_work(params)
        time = time_days_ago(params.first['max_orphaned_age_in_days'])
        Models::OrphanDisk.where('created_at < ?', time).any?
      end

      def self.time_days_ago(days)
        Time.now - (days * 24 * 60 * 60)
      end

      def self.schedule_message
        "clean up orphan disks"
      end

      def initialize(params = {})
        logger.debug("ScheduledOrphanCleanup initialized with params: #{params.inspect}")
        @max_orphaned_age_in_days = params['max_orphaned_age_in_days']
        cloud = params.fetch(:cloud) { Config.cloud }
        @disk_manager = DiskManager.new(cloud, logger)
      end

      def perform
        time = self.class.time_days_ago(@max_orphaned_age_in_days)
        logger.info("Started cleanup of orphan disks and orphan snapshots older than #{time}")

        old_orphans = Models::OrphanDisk.where('created_at < ?', time)
        old_orphans_count = old_orphans.count
        stage = Config.event_log.begin_stage('Deleting orphan disks', old_orphans_count)
        old_orphans.each do |old_orphan|
          stage.advance_and_track("#{old_orphan.disk_cid}") do
            @disk_manager.delete_orphan_disk(old_orphan)
          end
        end
        "Deleted #{old_orphans_count} orphaned disk(s) older than #{time}"
      end
    end
  end
end
