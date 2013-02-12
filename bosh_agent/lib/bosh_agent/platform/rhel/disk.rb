# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/linux/disk'
require 'bosh_agent/platform/rhel'

module Bosh::Agent
  class Platform::Rhel::Disk < Platform::Linux::Disk

    def detect_block_device(disk_id)
      rescan_scsi_bus
      dev_path = "/sys/bus/scsi/devices/0:0:#{disk_id}:0/block:*"
      while Dir.glob(dev_path, 0).empty?
        @logger.info("Waiting for #{dev_path}")
        sleep 0.1
      end
      dev = File.basename(Dir.glob(dev_path, 0).first)
      dev.gsub /^block:/, ""
    end

  end
end
