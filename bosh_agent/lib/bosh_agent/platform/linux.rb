# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/unix'

module Bosh::Agent

  class Platform::Linux < Platform::UNIX
    def initialize(disk, logrotate, password, network)
      super(disk, logrotate, password, network)
    end
  end
end
