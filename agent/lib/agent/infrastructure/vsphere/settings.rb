# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Vsphere::Settings
    DEFAULT_CDROM_RETRY_WAIT = 0.5

    attr_accessor :cdrom_retry_wait

    def initialize
      base_dir = Bosh::Agent::Config.base_dir
      @logger = Bosh::Agent::Config.logger
      @settings_file = Bosh::Agent::Config.settings_file
      @cdrom_retry_wait = DEFAULT_CDROM_RETRY_WAIT
      @cdrom_settings_mount_point = File.join(base_dir, 'bosh', 'settings')
    end

    def load_settings
      begin
        load_cdrom_settings
      rescue LoadSettingsError
        if File.exist?(@settings_file)
          @logger.info("Falling back to cached settings file")
          load_settings_file(@settings_file)
        else
          raise LoadSettingsError, "No cdrom or cached settings.json"
        end
      end
      Bosh::Agent::Config.settings = @settings
    end

    def load_cdrom_settings
      check_cdrom
      create_cdrom_settings_mount_point
      mount_cdrom

      env_file = File.join(@cdrom_settings_mount_point, 'env')

      begin
        settings_json = File.read(env_file)
        @settings = Yajl::Parser.new.parse(settings_json)

        File.open(@settings_file, 'w') { |f| f.write(settings_json) }
      rescue
        raise Bosh::Agent::LoadSettingsError, 'Failed to read/write env/settings.json'
      ensure
        umount_cdrom
        eject_cdrom
      end
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
          @logger.info("Waiting for /dev/cdrom (ENOMEDIUM): #{e.inspect}")
        end
        sleep @cdrom_retry_wait
      end

      # Second read - invoke udevadmin settle
      begin
        read_cdrom_byte
      rescue => e
        # Do nothing
      ensure
        # udevadm settle default timeout is 120 seconds
        udevadm_settle_out = udevadm_settle
        @logger.info("udevadm: #{udevadm_settle_out}")
      end

      # Read successfuly from cdrom for 2.5 seconds
      5.times do
        begin
          read_cdrom_byte
        rescue Errno::EBUSY
          @logger.info("Waiting for udev cdrom-id (EBUSY)")
          # do nothing
        rescue Errno::ENOTBLK, Errno::ENOMEDIUM # 1.8: Errno::E123
          @logger.info("Waiting for /dev/cdrom (ENOMEDIUM or ENOTBLK)")
          # do nothing
        end
        sleep @cdrom_retry_wait
      end

      begin
        read_cdrom_byte
      rescue Errno::ENOTBLK, Errno::EBUSY, Errno::ENOMEDIUM # 1.8: Errno::E123
        raise Bosh::Agent::LoadSettingsError, "No bosh cdrom env: #{e.inspect}"
      end
    end

    def udevadm_settle
      `/sbin/udevadm settle`
    end

    def read_cdrom_byte
      if File.blockdev?("/dev/cdrom")
        File.read("/dev/cdrom", 1)
      else
        @logger.info("/dev/cdrom not a blockdev")
        raise Errno::ENOTBLK
      end
    end

    def create_cdrom_settings_mount_point
      FileUtils.mkdir_p(@cdrom_settings_mount_point)
      FileUtils.chmod(0700, @cdrom_settings_mount_point)
    end

    def mount_cdrom
      output = `mount /dev/cdrom #{@cdrom_settings_mount_point} 2>&1`
      raise Bosh::Agent::LoadSettingsError,
        "Failed to mount settings on #{@cdrom_settings_mount_point}: #{output}" unless $?.exitstatus == 0
    end

    def load_settings_file(settings_file)
      if File.exists?(settings_file)
        settings_json = File.read(settings_file)
        @settings = Yajl::Parser.new.parse(settings_json)
      else
        raise LoadSettingsError, "No settings file #{settings_file}"
      end
    end

    def umount_cdrom
      `umount #{@cdrom_settings_mount_point} 2>&1`
    end

    def eject_cdrom
      `eject /dev/cdrom`
    end

  end
end
