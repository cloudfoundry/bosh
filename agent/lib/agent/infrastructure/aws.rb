
module Bosh::Agent
  class Infrastructure::Aws
    require 'agent/infrastructure/aws/settings'
    require 'agent/infrastructure/aws/registry'
    require 'agent/infrastructure/aws/disk'

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
      Settings.new.get_network_settings
    end

    def setup_networking
      # Nothing to do
    end

  end
end
