# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  module Infrastructure::Vsphere; end
  class Infrastructure::Vcloud
    require 'bosh_agent/infrastructure/vsphere/settings'

    def load_settings
      Infrastructure::Vsphere::Settings.new.load_settings
    end

    def get_network_settings(network_name, properties)
      # Nothing to do
    end

  end
end
