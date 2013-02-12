# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/linux'

require 'sys/filesystem'
include Sys

module Bosh::Agent

  class Platform::Linux::Disk

    VSPHERE_DATA_DISK = "/dev/sdb"
    DEV_PATH_TIMEOUT=180

    def initialize
      @config   ||= Bosh::Agent::Config
      @platform_name ||= @config.platform_name
      @logger   ||= @config.logger
      @store_dir ||= File.join(@config.base_dir, 'store')
      @dev_path_timeout ||= DEV_PATH_TIMEOUT
    end

    def mount_persistent_disk(cid)
      FileUtils.mkdir_p(@store_dir)
      disk = lookup_disk_by_cid(cid)
      partition = "#{disk}1"
      if File.blockdev?(partition) && !mount_exists?(partition)
        mount(partition, store_path)
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
          raise Bosh::Agent::FatalError, "Lookup disk failed, unsupported infrastructure #@infrastructure_name"
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
          blockdev = detect_block_device(disk_id)
          File.join('/dev', blockdev)
        when "aws"
          # AWS passes in the device name
          get_available_path(disk_id)
        when "openstack"
          # OpenStack passes in the device name
          get_available_path(disk_id)
        else
          raise Bosh::Agent::FatalError, "Lookup disk failed, unsupported infrastructure #@infrastructure_name"
      end
    end

    def detect_block_device(disk_id)
      raise Bosh::Agent::UnimplementedMethod.new
    end

protected
    def rescan_scsi_bus
      Bosh::Exec.sh "rescan-scsi-bus.sh"
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
      Bosh::Exec.sh "mount #{partition} #{path}"
    end

    def mount_exists?(partition)
      Filesystem.mounts.select{|mount| mount.name == partition}.any?
    end

  end
end
