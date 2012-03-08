module Bosh::Agent
  class Infrastructure::Aws::Disk

    def initialize
    end

    def logger
      Bosh::Agent::Config.logger
    end

    DEV_PATH_TIMEOUT=180
    def dev_path_timeout
      DEV_PATH_TIMEOUT
    end

    def get_xvd_path(dev_path)
      dev_path_suffix = dev_path.match("/dev/sd(.*)")[1]
      "/dev/xvd#{dev_path_suffix}"
    end

    def get_data_disk_device_name
      settings = Bosh::Agent::Config.settings
      dev_path = settings['disks']['ephemeral']
      unless dev_path
        raise Bosh::Agent::FatalError, "Unknown data or ephemeral disk"
      end

      xvd_dev_path = get_xvd_path(dev_path)
      if Dir[dev_path, xvd_dev_path].empty?
        raise Bosh::Agent::FatalError, "data path #{dev_path} or #{xvd_dev_path} not found"
      end

      return xvd_dev_path unless Dir[xvd_dev_path].empty?
      dev_path
    end

    def lookup_disk_by_cid(cid)
      settings = Bosh::Agent::Config.settings
      dev_path = settings['disks']['persistent'][cid]
      unless dev_path
        raise Bosh::Agent::FatalError, "Unknown persistent disk: #{cid}"
      end

      xvd_dev_path = get_xvd_path(dev_path)

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

  end
end
