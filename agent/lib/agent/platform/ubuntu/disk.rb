# Copyright (c) 2009-2012 VMware, Inc.

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

    DEV_PATH_TIMEOUT=180
    def dev_path_timeout
      DEV_PATH_TIMEOUT
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

    def mount_entry(partition)
      File.read('/proc/mounts').lines.select { |l| l.match(/#{partition}/) }.first
    end

    def lookup_disk_by_cid(cid)
      settings = Bosh::Agent::Config.settings
      disk_id = settings['disks']['persistent'][cid]

      unless disk_id
        raise Bosh::Agent::FatalError, "Unknown persistent disk: #{cid}"
      end

      case Bosh::Agent::Config.infrastructure_name
      when "vsphere"
        # VSphere passes in scsi disk id
        sys_path = detect_block_device(disk_id)
        blockdev = File.basename(sys_path)
        File.join('/dev', blockdev)
      when "aws"
        # AWS passes in the device name
        xvd_dev_path = get_xvd_path(disk_id)
        get_available_path(disk_id, xvd_dev_path)
      when "openstack"
        # OpenStack passes in the device name
        vd_dev_path = get_vd_path(disk_id)
        get_available_path(disk_id, vd_dev_path)
      else
        raise Bosh::Agent::FatalError, "Lookup disk failed, unsupported infrastructure " \
                                       "#{Bosh::Agent::Config.infrastructure_name}"
      end
    end

    def rescan_scsi_bus
      `/sbin/rescan-scsi-bus.sh`
      unless $?.exitstatus == 0
        raise Bosh::Agent::FatalError, "Failed to run /sbin/rescan-scsi-bus.sh (exit code #{$?.exitstatus})"
      end
    end

    def detect_block_device(disk_id)
      rescan_scsi_bus
      dev_path = "/sys/bus/scsi/devices/2:0:#{disk_id}:0/block/*"
      while Dir[dev_path].empty?
        logger.info("Waiting for #{dev_path}")
        sleep 0.1
      end
      Dir[dev_path].first
    end

    def get_xvd_path(dev_path)
      dev_path_suffix = dev_path.match("/dev/sd(.*)")[1]
      "/dev/xvd#{dev_path_suffix}"
    end

    def get_vd_path(dev_path)
      dev_path_suffix = dev_path.match("/dev/sd(.*)")
      dev_path_suffix.nil? ? dev_path : "/dev/vd#{dev_path_suffix[1]}"
    end

    def get_available_path(dev_path, xvd_dev_path)
      start = Time.now
      while Dir[dev_path, xvd_dev_path].empty?
        logger.info("Waiting for #{dev_path} or #{xvd_dev_path}")
        sleep 0.1
        if (Time.now - start) > dev_path_timeout
          raise Bosh::Agent::FatalError, "Timed out waiting for #{dev_path} or #{xvd_dev_path}"
        end
      end

      return xvd_dev_path unless Dir[xvd_dev_path].empty?
      dev_path
    end

    VSPHERE_DATA_DISK = "/dev/sdb"
    def get_data_disk_device_name
      case Bosh::Agent::Config.infrastructure_name
      when "vsphere"
        VSPHERE_DATA_DISK
      when "aws"
        settings = Bosh::Agent::Config.settings
        dev_path = settings['disks']['ephemeral']
        unless dev_path
          raise Bosh::Agent::FatalError, "Unknown data or ephemeral disk"
        end

        xvd_dev_path = get_xvd_path(dev_path)
        get_available_path(dev_path, xvd_dev_path)
      when "openstack"
        settings = Bosh::Agent::Config.settings
        dev_path = settings['disks']['ephemeral']
        unless dev_path
          raise Bosh::Agent::FatalError, "Unknown data or ephemeral disk"
        end

        vd_dev_path = get_vd_path(dev_path)
        get_available_path(dev_path, vd_dev_path)
      else
        raise Bosh::Agent::FatalError, "Lookup disk failed, unsupported infrastructure " \
                                       "#{Bosh::Agent::Config.infrastructure_name}"
      end
    end

  end
end
