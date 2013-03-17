# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Aws
    require 'bosh_agent/infrastructure/aws/settings'
    require 'bosh_agent/infrastructure/aws/registry'

    def load_settings
      Settings.new.load_settings
    end

    def get_network_settings(network_name, properties)
      Settings.new.get_network_settings(network_name, properties)
    end

    def network_config_type
      NETWORK_TYPE[:dhcp]
    end

    def disk_type
      DISK_TYPE[:other]
    end

  end
end
