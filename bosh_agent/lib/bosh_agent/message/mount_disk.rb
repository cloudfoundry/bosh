# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/mounter'

module Bosh::Agent
  module Message
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

          setup_disk
        end
      end

      def update_settings
        Bosh::Agent::Config.settings = Bosh::Agent::Settings.load
      end

      def setup_disk
        disk = Bosh::Agent::Config.platform.lookup_disk_by_cid(@cid)
        partition = "#{disk}1"

        logger.info("setup disk settings: #{settings.inspect}")

        read_disk_attempts = 300
        read_disk_attempts.downto(0) do |n|
          begin
            # Parition table is blank
            disk_data = File.read(disk, 512)

            if disk_data == "\x00"*512
              logger.info("Found blank disk #{disk}")
            else
              logger.info("Disk has partition table")
              logger.info(`sfdisk -Llq #{disk} 2> /dev/null`)
            end
            break
          rescue => e
            # Do nothing - we'll retry
            logger.info("Re-trying reading from #{disk}")
          end

          if n == 0
            raise Bosh::Agent::MessageHandlerError, "Unable to read from new disk"
          end
          sleep 1
        end

        if File.blockdev?(disk) && DiskUtil.ensure_no_partition?(disk, partition)
          full_disk = ",,L\n"
          logger.info("Partitioning #{disk}")

          Bosh::Agent::Util.partition_disk(disk, full_disk)

          mke2fs_options = ["-t ext4", "-j"]
          mke2fs_options << "-E lazy_itable_init=1" if Bosh::Agent::Util.lazy_itable_init_enabled?
          `/sbin/mke2fs #{mke2fs_options.join(" ")} #{partition}`
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

        Mounter.new(logger).mount(partition, mountpoint)
      end

      def self.long_running?; true; end
    end

  end
end
