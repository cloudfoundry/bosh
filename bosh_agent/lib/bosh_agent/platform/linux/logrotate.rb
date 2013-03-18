# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/linux'

module Bosh::Agent
  class Platform::Linux::Logrotate
    DEFAULT_MAX_LOG_FILE_SIZE = "50M"

    def initialize(template_dir)
      @config ||= Bosh::Agent::Config
      @logger ||= @config.logger
      @max_log_size ||= DEFAULT_MAX_LOG_FILE_SIZE
      @app_group ||= BOSH_APP_GROUP
      @template_src = File.join template_dir, "logrotate.erb"
      @template_dst = File.join @config.system_root, "etc", "logrotate.d", @app_group
    end

    def install(spec={})
      base_dir = @config.base_dir
      size = max_log_file_size(spec['properties'])
      @logger.debug "Compiling template #@template_src to #@template_dst"
      Template.write do |t|
        t.src @template_src
        t.dst @template_dst
      end
    end

private
    def max_log_file_size(properties)
      if properties && properties.has_key?('logging') && properties['logging'].has_key?('max_log_file_size')
        properties['logging']['max_log_file_size']
      else
        @max_log_size
      end
    end

  end
end
