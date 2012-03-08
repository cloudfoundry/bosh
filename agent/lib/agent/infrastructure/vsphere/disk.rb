module Bosh::Agent
  class Infrastructure::Vsphere::Disk

    def initialize
    end

    def logger
      Bosh::Agent::Config.logger
    end

    DATA_DISK = "/dev/sdb"
    def get_data_disk_device_name
      DATA_DISK
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

  end
end
