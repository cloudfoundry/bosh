require 'fileutils'

module Bosh::Agent
  module Message

    class MigrateDisk < Base
      def self.process(args)
        #logger = Bosh::Agent::Config.logger
        #logger.info("MigrateDisk:" + args.inspect)

        self.new.migrate(args)
        {}
      end

      def migrate(args)
        logger.info("MigrateDisk:" + args.inspect)
        @old_cid, @new_cid = args

        300.times do |n|
          break if `lsof -t +D #{store_path}`.empty? && `lsof -t +D #{store_migration_target}`.empty?
          if n == 299
            raise Bosh::Agent::MessageHandlerError,
              "Failed to migrate store to new disk still processes with open files"
          end
          sleep 1
        end

        # TODO: remount old store read-only
        if check_mountpoints
          logger.info("Copy data from old to new store disk")
          `(cd #{store_path} && tar cf - .) | (cd #{store_migration_target} && tar xpf -)`
        end

        unmount_store
        unmount_store_migration_target
        mount_new_store
      end

      def check_mountpoints
        Pathname.new(store_path).mountpoint? && Pathname.new(store_migration_target).mountpoint?
      end

      def unmount_store
        `umount #{store_path}`
      end

      def unmount_store_migration_target
        `umount #{store_migration_target}`
      end

      def mount_new_store
        disk = DiskUtil.lookup_disk_by_cid(@new_cid)
        partition = "#{disk}1"
        logger.info("Mounting: #{partition} #{store_path}")
        `mount #{partition} #{store_path}`
        unless $?.exitstatus == 0
          raise Bosh::Agent::MessageHandlerError, "Failed to mount: #{partition} #{store_path} (exit code #{$?.exitstatus})"
        end
      end

      def self.long_running?; true; end
    end

    class MountDisk < Base
      def self.process(args)
        new(args).mount
      end

      def initialize(args)
        @cid = args.first
      end

      def mount
        if Bosh::Agent::Config.configure
          update_settings
          logger.info("MountDisk: #{@cid} - #{settings['disks'].inspect}")

          rescan_scsi_bus
          setup_disk
        end
      end

      def update_settings
        Bosh::Agent::Config.settings = Bosh::Agent::Util.settings
      end

      def rescan_scsi_bus
        `/sbin/rescan-scsi-bus.sh`
        unless $?.exitstatus == 0
          raise Bosh::Agent::MessageHandlerError, "Failed to run /sbin/rescan-scsi-bus.sh (exit code #{$?.exitstatus})"
        end
      end

      def setup_disk
        disk = DiskUtil.lookup_disk_by_cid(@cid)
        partition = "#{disk}1"

        logger.info("setup disk settings: #{settings.inspect}")

        if File.blockdev?(disk) && Dir["#{disk}[1-9]"].empty?
          full_disk = ",,L\n"
          logger.info("Partitioning #{disk}")

          Bosh::Agent::Util.partition_disk(disk, full_disk)

          `/sbin/mke2fs -t ext4 -j #{partition}`
          unless $?.exitstatus == 0
            raise Bosh::Agent::MessageHandlerError, "Failed create file system (#{$?.exitstatus})"
          end
        elsif File.blockdev?(partition)
          logger.info("Found existing partition on #{disk}")
          # Do nothing
        else
          raise Bosh::Agent::MessageHandlerError, "Unable to format #{disk}"
        end

        mount_persistent_disk(partition)
        {}
      end

      def mount_persistent_disk(partition)
        store_mountpoint = File.join(base_dir, 'store')

        if Pathname.new(store_mountpoint).mountpoint?
          logger.info("Mounting persistent disk store migration target")
          mountpoint = File.join(base_dir, 'store_migraton_target')
        else
          logger.info("Mounting persistent disk store")
          mountpoint = store_mountpoint
        end

        FileUtils.mkdir_p(mountpoint)
        FileUtils.chmod(0700, mountpoint)

        logger.info("Mount #{partition} #{mountpoint}")
        `mount #{partition} #{mountpoint}`
        unless $?.exitstatus == 0
          raise Bosh::Agent::MessageHandlerError, "Failed mount #{partition} on #{mountpoint} #{$?.exitstatus}"
        end
      end

      def self.long_running?; true; end

    end

    class UnmountDisk < Base
      def self.process(args)
        self.new.unmount(args)
        {}
      end

      def unmount(args)
        cid = args.first
        disk = DiskUtil.lookup_disk_by_cid(cid)
        partition = "#{disk}1"

        if DiskUtil.mount_entry(partition)
          block, mountpoint = DiskUtil.mount_entry(partition).split

          until `lsof -t +D /var/vcap/store`.empty?
            sleep 1
          end

          `umount #{mountpoint}`
          unless $?.exitstatus == 0
            raise Bosh::Agent::MessageHandlerError, "Failed to umount #{partition} on #{mountpoint} #{$?.exitstatus}"
          end
        end
      end


      def self.long_running?; true; end
    end

    class DiskUtil
      class << self
        def logger
          Bosh::Agent::Config.logger
        end

        def lookup_disk_by_cid(cid)
          settings = Bosh::Agent::Config.settings
          disk_id = settings['disks']['persistent'][cid]
          sys_path = detect_block_device(disk_id)
          blockdev = File.basename(sys_path)
          File.join('/dev', blockdev)
        end

        def detect_block_device(disk_id)
          dev_path = "/sys/bus/scsi/devices/2:0:#{disk_id}:0/block/*"
          while Dir[dev_path].empty?
            logger.info("Waiting for #{dev_path}")
            sleep 0.1
          end
          Dir[dev_path].first
        end

        def mount_entry(partition)
          File.read('/proc/mounts').lines.select { |l| l.match(/#{partition}/) }.first
        end
      end
    end

  end
end
