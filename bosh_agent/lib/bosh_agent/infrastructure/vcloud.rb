# Copyright (c) 2009-2012 VMware, Inc.

require 'forwardable'
require 'bosh_agent/infrastructure/vsphere'

module Bosh::Agent
  class Infrastructure::Vcloud
    extend Forwardable

    def initialize
      @vsphere = Infrastructure::Vsphere.new
    end

    def_delegators :@vsphere, :load_settings, :get_network_settings
  end
end
