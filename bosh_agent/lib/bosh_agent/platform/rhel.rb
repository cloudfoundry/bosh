module Bosh::Agent
  module Platform::Rhel
    class Adapter < Platform::Linux::Adapter
      require 'bosh_agent/platform/linux/disk'
      require 'bosh_agent/platform/linux/logrotate'
      require 'bosh_agent/platform/rhel/network'
      require 'bosh_agent/platform/linux/password'

      def initialize
        template_dir = File.expand_path('rhel/templates', File.dirname(__FILE__))
        super(Platform::Linux::Disk.new,
              Platform::Linux::Logrotate.new(template_dir),
              Platform::Linux::Password.new,
              Network.new(template_dir))
      end
    end
  end
end
