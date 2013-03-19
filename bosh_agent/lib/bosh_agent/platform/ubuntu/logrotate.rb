# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/ubuntu'
require 'bosh_agent/platform/linux/logrotate'

module Bosh::Agent
  class Platform::Ubuntu::Logrotate < Platform::Linux::Logrotate

    def initialize
      super(File.join File.dirname(__FILE__), 'templates')
    end

  end
end
