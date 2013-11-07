require 'bosh_agent/disk_util'

module Bosh::Agent
  module Message

    # Migrates persistent data from the old persistent disk to the new
    # persistent disk.
    #
    # This message assumes that two mount messages have been received
    # and processed: one to mount the old disk at /var/vcap/store and
    # a second to mount the new disk at /var/vcap/store_migraton_target
    # (sic).
    class MigrateDisk < Base
      def self.long_running?; true; end

      def self.process(args)
        #logger = Bosh::Agent::Config.logger
        #logger.info("MigrateDisk:" + args.inspect)

        self.new.migrate(args)
        {}
      end

      def migrate(args)
        logger.info("MigrateDisk:" + args.inspect)
        @old_cid, @new_cid = args

        DiskUtil.umount_guard(store_path)

        Bosh::Agent::Config.platform.mount_persistent_disk(@old_cid, read_only: true)

        if check_mountpoints
          logger.info("Copy data from old to new store disk")
          `(cd #{store_path} && tar cf - .) | (cd #{store_migration_target} && tar xpf -)`
        end

        DiskUtil.umount_guard(store_path)
        DiskUtil.umount_guard(store_migration_target)

        Bosh::Agent::Config.platform.mount_persistent_disk(@new_cid)
      end

      private
      def check_mountpoints
        Pathname.new(store_path).mountpoint? && Pathname.new(store_migration_target).mountpoint?
      end

    end
  end
end
