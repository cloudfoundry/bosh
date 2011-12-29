

module Bosh::Agent
  class Platform::Ubuntu::Disk

    def initialize
    end

    def logger
      Bosh::Agent::Config.logger
    end

    def base_dir
      Bosh::Agent::Config.base_dir
    end

    def store_path
      File.join(base_dir, 'store')
    end

    def mount_persistent_disk(cid)
      FileUtils.mkdir_p(store_path)
      disk = lookup_disk_by_cid(cid)
      partition = "#{disk}1"
      if File.blockdev?(partition) && !mount_entry(partition)
        mount(partition, store_path)
      end
    end

    def mount(partition, path)
      logger.info("Mount #{partition} #{path}")
      `mount #{partition} #{path}`
      unless $?.exitstatus == 0
        raise Bosh::Agent::FatalError, "Failed to mount: #{partition} #{path}"
      end
    end

    def lookup_disk_by_cid(cid)
      settings = Bosh::Agent::Config.settings
      disk_id = settings['disks']['persistent'][cid]

      unless disk_id
        raise Bosh::Agent::FatalError, "Unknown persistent disk: #{cid}"
      end
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
