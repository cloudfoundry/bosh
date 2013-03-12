# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/infrastructure/aws/settings'
require 'bosh_agent/infrastructure/aws/registry'

module Bosh::Agent
  class Infrastructure::Aws

    def load_settings
      Settings.new.load_settings
    end

    def get_network_settings(_, properties)
      Settings.new.get_network_settings(properties["type"])
    end

    def network_config_type
      DHCP_NETWORK_TYPE
    end

    def disk_type

    end

  end
end
