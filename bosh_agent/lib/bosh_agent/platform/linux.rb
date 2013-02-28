# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent

  # The default implementation is all based on Ubuntu!
  class Platform::Linux
    require 'bosh_agent/platform/linux/disk'
    require 'bosh_agent/platform/linux/logrotate'
    require 'bosh_agent/platform/linux/password'
    require 'bosh_agent/platform/linux/network'
    require 'bosh_agent/platform/linux/service'

    attr_reader :ssh_service

    def initialize
      @disk ||= Disk.new
      @logrotate ||= Logrotate.new
      @password ||= Password.new
      @network ||= Network.new
      @ssh_service ||= Service.new("sshd")
    end

    def configure_disks(settings)
    end

    # FIXME: placeholder
    def mount_persistent_disk(cid)
      @disk.mount_persistent_disk(cid)
    end

    def update_logging(spec)
      @logrotate.install(spec)
    end

    def update_passwords(settings)
      @password.update(settings)
    end

    def lookup_disk_by_cid(cid)
      @disk.lookup_disk_by_cid(cid)
    end

    def get_data_disk_device_name
      @disk.get_data_disk_device_name
    end

    def setup_networking
      @network.setup_networking
    end

    def start_ssh_and_wait(timeout)
      @ssh_service.start_and_wait(timeout)
    end

    def stop_ssh_and_wait(timeout)
      @ssh_service.stop_and_wait(timeout)
    end

  end
end
