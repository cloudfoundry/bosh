
module Bosh::Agent
  class Platform::Ubuntu
    require 'agent/platform/ubuntu/disk'
    require 'agent/platform/ubuntu/logrotate'
    require 'agent/platform/ubuntu/password'

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

  end
end
