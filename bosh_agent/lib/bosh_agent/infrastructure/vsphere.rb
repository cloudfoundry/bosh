# Copyright (c) 2009-2012 VMware, Inc.
module Bosh::Agent
  class Infrastructure::Vsphere
    require 'bosh_agent/infrastructure/vsphere/settings'

    def initialize
      @settings = Settings.new
    end

    def load_settings
      @settings.load_settings
    end

    def network_config_type
      NETWORK_TYPE[:manual]
    end

    def disk_type
      DISK_TYPE[:scsi]
    end

    def get_network_settings(network_name, properties)
      # Do nothing
    end

  end
end
