# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Vsphere::Settings
    DEFAULT_CDROM_RETRY_WAIT = 0.5

    attr_accessor :cdrom_retry_wait

    def initialize
      base_dir = Bosh::Agent::Config.base_dir
      @logger = Bosh::Agent::Config.logger
      @cdrom_retry_wait = DEFAULT_CDROM_RETRY_WAIT
      @cdrom_settings_mount_point = File.join(base_dir, 'bosh', 'settings')
      @cdrom_device = nil
    end

    def cdrom_device
      unless @cdrom_device
        # only do this when not already done
        cd_drive = File.read("/proc/sys/dev/cdrom/info").slice(/drive name:\s*\S*/).slice(/\S*\z/)
        @cdrom_device = "/dev/#{cd_drive.strip}"
      end
      @cdrom_device
    end

    def load_settings
      load_cdrom_settings
    end

    def load_cdrom_settings
      check_cdrom
      create_cdrom_settings_mount_point
      mount_cdrom

      env_file = File.join(@cdrom_settings_mount_point, 'env')

      begin
        settings_json = File.read(env_file)
        @settings = Yajl::Parser.new.parse(settings_json)
      rescue
        raise Bosh::Agent::LoadSettingsError, 'Failed to read/write env/settings.json'
      ensure
        umount_cdrom
        eject_cdrom
      end
      @settings
    end

    def check_cdrom
      # Below we do a number of retries to work around race conditions both
      # when inserting a virtual cdrom in vSphere and how udev handles
      # detection of the new media.
      #
      # Part of what the udev cdrom-id helper will do is to open /dev/cdrom
      # with O_EXCL, which will give us EBUSY - however, the exact timing of
      # this is a little harder - so we retry.

      # First give the cdrom media a little time to get detected
      5.times do
        begin
          read_cdrom_byte
          break
        rescue => e
          @logger.info("Waiting for #{cdrom_device} (ENOMEDIUM): #{e.inspect}")
        end
        sleep @cdrom_retry_wait
      end

      # Second read - invoke udevadmin settle
      begin
        read_cdrom_byte
      rescue => e
        # Do nothing
      end

      begin
        # udevadm settle default timeout is 120 seconds
        udevadm_settle_out = udevadm_settle
        @logger.info("udevadm: #{udevadm_settle_out}")
      rescue
        raise Bosh::Agent::LoadSettingsError, "udevadm failed: #{e.inspect}"
      end

      # Read successfuly from cdrom for 2.5 seconds
      5.times do
        begin
          read_cdrom_byte
        rescue Errno::EBUSY
          @logger.info("Waiting for udev cdrom-id (EBUSY)")
          # do nothing
        rescue Errno::ENOMEDIUM # 1.8: Errno::E123
          @logger.info("Waiting for #{cdrom_device} (ENOMEDIUM or ENOTBLK)")
          # do nothing
        end
        sleep @cdrom_retry_wait
      end

      begin
        read_cdrom_byte
      rescue Errno::EBUSY, Errno::ENOMEDIUM # 1.8: Errno::E123
        raise Bosh::Agent::LoadSettingsError, "No bosh cdrom env: #{e.inspect}"
      end
    end

    def udevadm_settle
      if File.exists? "/sbin/udevadm"
        Bosh::Exec.sh "/sbin/udevadm settle"
      elsif File.exists? "/sbin/udevsettle"
        Bosh::Exec.sh "/sbin/udevsettle"
      else
        raise Bosh::Agent::LoadSettingsError, "No udevsettle"
      end
    end

    def read_cdrom_byte
      File.read(cdrom_device, 1)
    end

    def create_cdrom_settings_mount_point
      FileUtils.mkdir_p(@cdrom_settings_mount_point)
      FileUtils.chmod(0700, @cdrom_settings_mount_point)
    end

    def mount_cdrom
      result = Bosh::Exec.sh "mount #{cdrom_device} #@cdrom_settings_mount_point 2>&1"
      raise Bosh::Agent::LoadSettingsError,
        "Failed to mount settings on #@cdrom_settings_mount_point: #{result.output}" if result.failed?
    end

    def umount_cdrom
      Bosh::Exec.sh "umount #@cdrom_settings_mount_point 2>&1"
    end

    def eject_cdrom
      Bosh::Exec.sh "eject #{cdrom_device}"
    end

  end
end
