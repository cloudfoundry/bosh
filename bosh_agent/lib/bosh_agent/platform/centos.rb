module Bosh::Agent

  class Platform::Centos < Platform::Linux
    require 'bosh_agent/platform/centos/disk'
    require 'bosh_agent/platform/linux/logrotate'
    require 'bosh_agent/platform/rhel/network'
    require 'bosh_agent/platform/linux/password'

    def initialize
      logrotate_template_dir = File.expand_path('ubuntu/templates', File.dirname(__FILE__))
      network_template_dir = File.expand_path('rhel/templates', File.dirname(__FILE__))
      super(Disk.new,
            Platform::Linux::Logrotate.new(logrotate_template_dir),
            Platform::Linux::Password.new,
            Platform::Rhel::Network.new(network_template_dir))
    end
  end

end
