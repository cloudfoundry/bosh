
module Bosh::Agent
  class Platform::Ubuntu
    require 'agent/platform/ubuntu/disk'
    require 'agent/platform/ubuntu/logrotate'
    require 'agent/platform/ubuntu/password'
    require 'agent/platform/ubuntu/network'

    def configure_disks(settings)
    end

    # FIXME: placeholder
    def mount_persistent_disk(cid)
      Disk.new.mount_persistent_disk(cid)
    end

    def update_logging(spec)
      Logrotate.new(spec).install
    end

    def update_passwords(settings)
      Password.new.update(settings)
    end

    def lookup_disk_by_cid(cid)
      Disk.new.lookup_disk_by_cid(cid)
    end

    def get_data_disk_device_name
      Disk.new.get_data_disk_device_name
    end

    def setup_networking
      Network.new.setup_networking
    end

  end
end
