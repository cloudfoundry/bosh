module Bosh::Agent
  class Platform::Centos::Disk < Platform::Linux::Disk
    def detect_block_device(disk_id)
      device_path = "/sys/bus/scsi/devices/0:0:#{disk_id}:0/block/*"
      dirs = Dir.glob(device_path, 0)
      raise Bosh::Agent::DiskNotFoundError, "Unable to find disk #{device_path}" if dirs.empty?

      File.basename(dirs.first)
    end

    private

    def rescan_scsi_bus
      sh 'echo "- - -" > /sys/class/scsi_host/host0/scan'
    end
  end
end
