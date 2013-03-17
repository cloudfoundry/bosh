# Copyright (c) 2009-2012 VMware, Inc.

require 'bosh_agent/platform/linux'

module Bosh::Agent
  class Platform::Rhel < Platform::Linux

    require 'bosh_agent/platform/rhel/disk'
    require 'bosh_agent/platform/rhel/logrotate'
    require 'bosh_agent/platform/rhel/password'
    require 'bosh_agent/platform/rhel/network'

    def initialize
      super(Disk.new, Logrotate.new, Password.new, Network.new)
    end

  end
end
