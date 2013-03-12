# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/infrastructure/vsphere/settings'

module Bosh::Agent
  class Infrastructure::Vsphere

    def initialize
      @settings = Settings.new
    end

    def load_settings
      @settings.load_settings
    end

    def network_config_type
      MANUAL_NETWORK_TYPE
    end

    def disk_type
      "scsi"
    end

    def get_network_settings(_, properties)
      # Do nothing
    end

  end
end
