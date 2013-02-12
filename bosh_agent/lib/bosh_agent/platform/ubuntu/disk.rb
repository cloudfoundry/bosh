# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/ubuntu'
require 'bosh_agent/platform/linux/disk'

module Bosh::Agent
  class Platform::Ubuntu::Disk < Platform::Linux::Disk

protected
    def detect_block_device(disk_id)
      rescan_scsi_bus
      dev_path = "/sys/bus/scsi/devices/2:0:#{disk_id}:0/block/*"
      while Dir[dev_path].empty?
        logger.info("Waiting for #{dev_path}")
        sleep 0.1
      end
      File.basename(Dir[dev_path].first)
    end

  end
end
