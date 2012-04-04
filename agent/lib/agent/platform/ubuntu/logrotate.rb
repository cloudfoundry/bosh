# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Platform::Ubuntu::Logrotate
    DEFAULT_MAX_LOG_FILE_SIZE = "50M"

    def initialize(spec)
      @spec = spec
      @system_root = Bosh::Agent::Config.system_root
    end

    def install
      base_dir = Bosh::Agent::Config.base_dir
      size = max_log_file_size

      Template.write do |t|
        t.src 'platform/ubuntu/templates/logrotate.erb'
        t.dst "#{@system_root}/etc/logrotate.d/#{BOSH_APP_GROUP}"
      end
    end

    def max_log_file_size
      properties = @spec['properties']
      if properties && properties.key?('logging') && properties['logging'].key?('max_log_file_size')
        properties['logging']['max_log_file_size']
      else
        DEFAULT_MAX_LOG_FILE_SIZE
      end
    end
  end
end
