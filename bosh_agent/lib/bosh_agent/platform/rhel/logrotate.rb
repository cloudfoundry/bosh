# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/linux/logrotate'

module Bosh::Agent::Platform
  class Platform::Rhel::Logrotate < Platform::Linux::Logrotate

    def initialize
      super(File.join File.dirname(__FILE__), 'templates')
    end

  end
end
