# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Platform::Linux::Logrotate
    DEFAULT_MAX_LOG_FILE_SIZE = "50M"

    def initialize
    end

    def install(spec)
      size = max_log_file_size(spec['properties'])
      base_dir = Bosh::Agent::Config.base_dir

      Template.write do |t|
        t.src File.join(File.dirname(__FILE__), 'templates/logrotate.erb')
        t.dst "#{Bosh::Agent::Config.system_root}/etc/logrotate.d/#{BOSH_APP_GROUP}"
      end
    end

    def max_log_file_size(properties)
      if properties && properties.key?('logging') && properties['logging'].key?('max_log_file_size')
        properties['logging']['max_log_file_size']
      else
        DEFAULT_MAX_LOG_FILE_SIZE
      end
    end
  end
end
