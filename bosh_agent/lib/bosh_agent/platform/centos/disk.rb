module Bosh::Agent
  class Platform::Centos::Disk < Platform::Linux::Disk
    def detect_block_device(disk_id)
      device_path = "/sys/bus/scsi/devices/#{root_disk_scsi_host_id}:0:#{disk_id}:0/block/*"
      dirs = Dir.glob(device_path)
      raise Bosh::Agent::DiskNotFoundError, "Unable to find disk #{device_path}" if dirs.empty?

      File.basename(dirs.first)
    end

    private

    def rescan_scsi_bus
      File.open("/sys/class/scsi_host/host#{root_disk_scsi_host_id}/scan", 'w') do |file|
        file.puts '- - -'
      end
    end

    def root_disk_scsi_host_id
      Dir.glob('/sys/bus/scsi/devices/*:0:0:0/block/*').each do |device|
        if %r{/(?<host_id>\d):0:0:0/.*/sda} =~ device
          return host_id
        end
      end
    end
  end
end
