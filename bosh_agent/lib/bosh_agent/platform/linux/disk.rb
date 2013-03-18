# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/linux'

require 'sigar'
require 'retryable'

module Bosh::Agent

  class Platform::Linux::Disk
    include Bosh::Exec

    VSPHERE_DATA_DISK = "/dev/sdb"
    DEV_PATH_TIMEOUT=180
    DISK_RETRY_MAX_DEFAULT = 30

    def initialize
      @config   ||= Bosh::Agent::Config
      @platform_name ||= @config.platform_name
      @logger   ||= @config.logger
      @store_dir ||= File.join(@config.base_dir, 'store')
      @dev_path_timeout ||= DEV_PATH_TIMEOUT
      @disk_retry_timeout = DISK_RETRY_MAX_DEFAULT
      @sigar = Sigar.new
    end

    def mount_persistent_disk(cid)
      FileUtils.mkdir_p(@store_dir)
      disk = lookup_disk_by_cid(cid)
      partition = "#{disk}1"
      if File.blockdev?(partition) && !mount_exists?(partition)
        mount(partition, @store_dir)
      end
    end

    def get_data_disk_device_name
      case @config.infrastructure_name
        when "vsphere"
          VSPHERE_DATA_DISK
        when "aws"
          settings = @config.settings
          dev_path = settings['disks']['ephemeral']
          unless dev_path
            raise Bosh::Agent::FatalError, "Unknown data or ephemeral disk"
          end
          get_available_path(dev_path)
        when "openstack"
          settings = @config.settings
          dev_path = settings['disks']['ephemeral']
          unless dev_path
            raise Bosh::Agent::FatalError, "Unknown data or ephemeral disk"
          end
          get_available_path(dev_path)
        else
          raise Bosh::Agent::FatalError, "Lookup disk failed, unsupported infrastructure #{Bosh::Agent::Config.infrastructure_name}"
      end
    end
    def lookup_disk_by_cid(cid)
      settings = @config.settings
      disk_id = settings['disks']['persistent'][cid]

      unless disk_id
        raise Bosh::Agent::FatalError, "Unknown persistent disk: #{cid}"
      end

      case @config.infrastructure_name
        when "vsphere"
          # VSphere passes in scsi disk id
          get_available_scsi_path(disk_id)
        when "aws"
          # AWS passes in the device name
          get_available_path(disk_id)
        when "openstack"
          # OpenStack passes in the device name
          get_available_path(disk_id)
        else
          raise Bosh::Agent::FatalError, "Lookup disk failed, unsupported infrastructure #{Bosh::Agent::Config.infrastructure_name}"
      end
    end

    def get_available_scsi_path(disk_id)
      rescan_scsi_bus
      blockdev = nil
      Retryable.retryable(:tries=> @disk_retry_timeout, :on => Bosh::Agent::DiskNotFoundError, :sleep => lambda{|n| [2**(n-1), 10].min }) do
        blockdev = detect_block_device(disk_id)
      end
      File.join('/dev', blockdev)
    end

    def detect_block_device(disk_id)
      device_path = "/sys/bus/scsi/devices/2:0:#{disk_id}:0/block/*"
      dirs = Dir.glob(device_path, 0)
      raise Bosh::Agent::DiskNotFoundError, "Unable to find disk #{device_path}" if dirs.empty?

      File.basename(dirs.first)
    end

protected
    def rescan_scsi_bus
      sh "rescan-scsi-bus.sh"
    end

    def get_dev_paths(dev_path)
      dev_paths = [] << dev_path
      dev_path_suffix = dev_path.match("/dev/sd(.*)")
      unless dev_path_suffix.nil?
        dev_paths << "/dev/vd#{dev_path_suffix[1]}"  # KVM
        dev_paths << "/dev/xvd#{dev_path_suffix[1]}" # Xen
      end
      dev_paths
    end

    def get_available_path(dev_path)
      start = Time.now
      dev_paths = get_dev_paths(dev_path)
      while Dir.glob(dev_paths).empty?
        @logger.info("Waiting for #{dev_paths}")
        sleep 0.1
        if (Time.now - start) > @dev_path_timeout
          raise Bosh::Agent::FatalError, "Timed out waiting for #{dev_paths}"
        end
      end
      Dir.glob(dev_paths).last
    end

private
    def mount(partition, path)
      @logger.info("Mount #{partition} #{path}")
      sh "mount #{partition} #{path}"
    end

    def mount_exists?(partition)
      @sigar.file_system_list.select {|mount| mount.name == partition}.any?
    end

  end
end
