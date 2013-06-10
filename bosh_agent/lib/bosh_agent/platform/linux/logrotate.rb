# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Platform::Linux::Logrotate
    DEFAULT_MAX_LOG_FILE_SIZE = "50M"

    def initialize(template_dir)
      @logger = Bosh::Agent::Config.logger
      @template_src = File.join template_dir, "logrotate.erb"
      @template_dst = File.join Bosh::Agent::Config.system_root, "etc", "logrotate.d", BOSH_APP_GROUP
    end

    def install(spec={})
      # These local variables are used in the template context
      # (see Bosh::Agent::Template class implementation)
      base_dir = Bosh::Agent::Config.base_dir
      size = max_log_file_size(spec['properties'])
      @logger.debug "Compiling template #@template_src to #@template_dst"
      Template.write do |t|
        t.src @template_src
        t.dst @template_dst
      end
    end

    private
    def max_log_file_size(properties)
      (properties || {}).
          fetch('logging', {}).
          fetch('max_log_file_size', DEFAULT_MAX_LOG_FILE_SIZE)
    end
  end
end
