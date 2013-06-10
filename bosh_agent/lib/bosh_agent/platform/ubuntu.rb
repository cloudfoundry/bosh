# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent

  class Platform::Ubuntu < Platform::Linux
    require 'bosh_agent/platform/linux/disk'
    require 'bosh_agent/platform/linux/logrotate'
    require 'bosh_agent/platform/ubuntu/network'
    require 'bosh_agent/platform/linux/password'

    def initialize
      template_dir = File.expand_path('ubuntu/templates', File.dirname(__FILE__))
      super(Platform::Linux::Disk.new,
            Platform::Linux::Logrotate.new(template_dir),
            Platform::Linux::Password.new,
            Network.new(template_dir))
    end
  end

end
