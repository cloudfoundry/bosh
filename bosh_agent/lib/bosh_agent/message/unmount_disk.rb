require 'bosh_agent/disk_util'

module Bosh::Agent
  module Message
    class UnmountDisk < Base

      def self.long_running?; true; end

      def self.process(args)
        self.new.unmount(args)
      end

      def unmount(args)
        cid = args.first
        disk = Bosh::Agent::Config.platform.lookup_disk_by_cid(cid)
        partition = "#{disk}1"

        if DiskUtil.mount_entry(partition)
          @block, @mountpoint = DiskUtil.mount_entry(partition).split
          DiskUtil.umount_guard(@mountpoint)
          logger.info("Unmounted #{@block} on #{@mountpoint}")
          return {:message => "Unmounted #{@block} on #{@mountpoint}" }
        else
          return {:message => "Unknown mount for partition: #{partition}"}
        end
      end
    end
  end
end
