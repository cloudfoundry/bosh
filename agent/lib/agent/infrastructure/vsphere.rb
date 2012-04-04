# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Vsphere
    require 'agent/infrastructure/vsphere/settings'

    def load_settings
      Settings.new.load_settings
    end

    def get_network_settings(network_name, properties)
      # Nothing to do
    end

  end
end
