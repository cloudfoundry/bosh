module Bosh::Agent
  module  Platform::Centos
    class Adapter < Platform::Linux::Adapter
      require 'bosh_agent/platform/centos/disk'
      require 'bosh_agent/platform/linux/logrotate'
      require 'bosh_agent/platform/centos/network'
      require 'bosh_agent/platform/linux/password'

      def initialize
        logrotate_template_dir = File.expand_path('ubuntu/templates', File.dirname(__FILE__))
        network_template_dir = File.expand_path('centos/templates', File.dirname(__FILE__))
        super(Disk.new,
              Platform::Linux::Logrotate.new(logrotate_template_dir),
              Platform::Linux::Password.new,
              Platform::Centos::Network.new(network_template_dir))
      end
    end
  end
end
