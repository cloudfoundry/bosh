# Copyright (c) 2009-2012 VMware, Inc.

require "bosh_agent/platform/linux"

module Bosh::Agent
  class Platform::Redhat < Platform::Linux

    require "bosh_agent/platform/redhat/disk"
    require "bosh_agent/platform/redhat/network"

    def initialize
      @disk ||= Disk.new
      @network ||= Network.new

      super
    end

  end
end
