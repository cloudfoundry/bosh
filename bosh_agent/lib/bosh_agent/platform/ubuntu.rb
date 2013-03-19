# Copyright (c) 2009-2012 VMware, Inc.

require 'bosh_agent/platform/linux'

module Bosh::Agent
  class Platform::Ubuntu < Platform::Linux
    require 'bosh_agent/platform/ubuntu/disk'
    require 'bosh_agent/platform/ubuntu/logrotate'
    require 'bosh_agent/platform/ubuntu/password'
    require 'bosh_agent/platform/ubuntu/network'

    def initialize
      super(Disk.new, Logrotate.new, Password.new, Network.new)
    end

  end
end
