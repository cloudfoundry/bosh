
module Bosh::Agent
  class Infrastructure::Vsphere
    require 'agent/infrastructure/vsphere/settings'
    require 'agent/infrastructure/vsphere/disk'
    require 'agent/infrastructure/vsphere/network'

    def load_settings
      Settings.new.load_settings
    end

    def get_data_disk_device_name
      Disk.new.get_data_disk_device_name
    end

    def lookup_disk_by_cid(cid)
      Disk.new.lookup_disk_by_cid(cid)
    end

    def get_network_settings
      nil
    end

    def setup_networking
      Network.new.setup_networking
    end

  end
end
