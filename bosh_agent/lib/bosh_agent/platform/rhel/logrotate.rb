# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/linux/logrotate'
require 'bosh_agent/platform/rhel'

module Bosh::Agent
  class Platform::Rhel::Logrotate < Platform::Linux::Logrotate

    def initialize
      super(File.join File.dirname(__FILE__), 'templates')
    end

  end
end
