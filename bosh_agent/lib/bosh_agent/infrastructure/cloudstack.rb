# Copyright (c) 2009-2012 VMware, Inc.
# Copyright (c) 2013 Nippon Telegraph and Telephone Corporation

module Bosh::Agent
  class Infrastructure::Cloudstack
    require 'bosh_agent/infrastructure/cloudstack/settings'
    require 'bosh_agent/infrastructure/cloudstack/registry'

    def load_settings
      Settings.new.load_settings
    end

    def get_network_settings(network_name, properties)
      Settings.new.get_network_settings(network_name, properties)
    end

  end
end
