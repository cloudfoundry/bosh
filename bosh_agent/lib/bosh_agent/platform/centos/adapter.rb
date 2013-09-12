module Bosh::Agent
  module  Platform::Centos
    class Adapter < Platform::Linux::Adapter
      require 'bosh_agent/platform/centos/disk'
      require 'bosh_agent/platform/linux/logrotate'
      require 'bosh_agent/platform/centos/network'
      require 'bosh_agent/platform/linux/password'

      def initialize
        template_dir = File.expand_path('templates', File.dirname(__FILE__))
        super(Disk.new,
              Platform::Linux::Logrotate.new(template_dir),
              Platform::Linux::Password.new,
              Platform::Centos::Network.new(template_dir))
      end
    end
  end
end
