# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent

  class Platform::Linux < Platform::UNIX
    require 'bosh_agent/platform/linux/disk'
    require 'bosh_agent/platform/linux/logrotate'
    require 'bosh_agent/platform/linux/network'
    require 'bosh_agent/platform/linux/password'

    def initialize(disk, logrotate, password, network)
      super
    end
  end

end
