module Bosh::Director
  module Jobs
    class OrphanDiskJob < BaseJob
      @queue = :normal

      def self.job_type
        :orphan_disk
      end

      def initialize(disk_cid)
        @disk_cid = disk_cid
        @orphan_disk_manager = OrphanDiskManager.new(Config.logger)
      end

      def self.enqueue(username, disk_cid, job_queue)
        job_queue.enqueue(username, Jobs::OrphanDiskJob, 'orphan disk', [disk_cid])
      end

      def perform
        persistent_disk = Models::PersistentDisk[:disk_cid => @disk_cid]
        event_log_stage = Config.event_log.begin_stage("Orphan disk", 1)
        event_log_stage.advance_and_track(@disk_cid) do
          if persistent_disk.nil?
            logger.info("disk #{@disk_cid} does not exist")
            Config.event_log.warn("Disk #{@disk_cid} does not exist. Orphaning is skipped")
          else
            logger.info("orphaning disk: #{@disk_cid}")
            @orphan_disk_manager.orphan_disk(persistent_disk)
          end
        end
        return "disk #{@disk_cid} orphaned"
      end
    end
  end
end
