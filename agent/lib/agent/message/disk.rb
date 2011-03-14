require 'fileutils'

module Bosh::Agent
  module Message

    class MigrateDisk
      def self.process(args)
        logger = Bosh::Agent::Config.logger
        logger.info("MigrateDisk:" + args.inspect)
        {}
      end
      def self.long_running?; true; end
    end

    class MountDisk
      def self.process(args)
        new(args).mount
      end

      def initialize(args)
        @base_dir = Bosh::Agent::Config.base_dir
        @logger = Bosh::Agent::Config.logger

        @settings = Bosh::Agent::Util.settings

        @cid = args.first
      end

      def mount
        @logger.info("MountDisk: #{@cid} - #{@settings['disks'].inspect}")
        if Bosh::Agent::Config.configure
          rescan_scsi_bus
          setup_disk
        end
      end

      def rescan_scsi_bus
        `/sbin/rescan-scsi-bus.sh`
        unless $?.exitstatus == 0
          raise Bosh::Agent::MessageHandlerError, "Failed to run /sbin/rescan-scsi-bus.sh (exit code #{$?.exitstatus})"
        end
      end

      def setup_disk
        disk_id = @settings['disks']['persistent'][@cid.to_s]

        @logger.info("setup disk @settings: #{@settings.inspect}")
        @logger.info("disk_id: #{disk_id}")

        sys_path = detect_block_device(disk_id)

        block = File.basename(sys_path)
        disk = File.join('/dev', block)
        partition = "#{disk}1"

        if File.blockdev?(disk) && Dir["#{disk}[1-9]"].empty?
          full_disk = ",,L\n"
          @logger.info("Partitioning #{disk}")

          Bosh::Agent::Util.partition_disk(disk, full_disk)

          `/sbin/mke2fs -j #{partition}`
          unless $?.exitstatus == 0
            raise Bosh::Agent::MessageHandlerError, "Failed create file system (#{$?.exitstatus})"
          end
        elsif File.blockdev?(partition)
          @logger.info("Found existing partition on #{disk}")
          # Do nothing
        else
          raise Bosh::Agent::MessageHandlerError, "Unable to format #{disk}"
        end

        store = File.join(@base_dir, 'store')
        FileUtils.mkdir_p(store)
        FileUtils.chmod(0700, store)

        @logger.info("mount #{partition} #{store}")
        `mount #{partition} #{store}`
        unless $?.exitstatus == 0
          raise Bosh::Agent::MessageHandlerError, "Failed mount #{partition} on #{store} #{$?.exitstatus}"
        end

        {}
      end

      def detect_block_device(disk_id)
        dev_path = "/sys/bus/scsi/devices/2:0:#{disk_id}:0/block/*"
        while Dir[dev_path].empty?
          @logger.info("Waiting for #{dev_path}")
          sleep 0.1
        end
        Dir[dev_path].first
      end
      def self.long_running?; true; end

    end

    class UnmountDisk
      def self.process(args)
        logger = Bosh::Agent::Config.logger
        logger.info("UnmountDisk:" + args.inspect)
        {}
      end
      def self.long_running?; true; end
    end

  end
end
