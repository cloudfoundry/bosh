
module Bosh::Agent
  class Infrastructure::Vsphere
    require 'agent/infrastructure/vsphere/settings'
    require 'agent/infrastructure/vsphere/disk'

    def load_settings
      Settings.new.load_settings
    end

    def setup_data_disk
      Disk.new.setup_data_disk
    end

    def mount_persistent_disk(cid)
      Disk.new.mount_persistent_disk(cid)
    end

  end
end
