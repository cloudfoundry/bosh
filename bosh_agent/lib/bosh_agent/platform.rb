module Bosh::Agent
  class UnknownPlatform < StandardError;
  end

  module Platform
    def self.platform(platform_name)
      case platform_name
        when 'ubuntu'
          template_dir = File.expand_path(File.join(File.dirname(__FILE__), 'platform/ubuntu/templates'))
          Platform::Linux::Adapter.new(Platform::Linux::Disk.new,
                                       Platform::Linux::Logrotate.new(template_dir),
                                       Platform::Linux::Password.new,
                                       Platform::Ubuntu::Network.new(template_dir))

        when 'centos'
          template_dir = File.expand_path(File.join(File.dirname(__FILE__), 'platform/centos/templates'))
          Platform::Linux::Adapter.new(Platform::Centos::Disk.new,
                                       Platform::Linux::Logrotate.new(template_dir),
                                       Platform::Linux::Password.new,
                                       Platform::Centos::Network.new(template_dir))
        else
          raise UnknownPlatform, "platform '#{platform_name}' not found"
      end
    end
  end
end
