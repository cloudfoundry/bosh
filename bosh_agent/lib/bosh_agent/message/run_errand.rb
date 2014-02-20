require 'open3'

module Bosh::Agent
  module Message
    class RunErrand
      def self.process(args)
        self.new(args).start
      end

      def self.long_running?
        true
      end

      def initialize(args)
        @base_dir = Bosh::Agent::Config.base_dir
        @logger = Bosh::Agent::Config.logger
      end

      def start
        state = Bosh::Agent::Config.state.to_hash

        job_templates = state.fetch('job', {}).fetch('templates', [])
        if job_templates.empty?
          raise Bosh::Agent::MessageHandlerError,
                "At least one job template is required to run an errand"
        end

        job_template_name = job_templates.first.fetch('name')

        env  = { 'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin' }
        cmd  = "#{@base_dir}/jobs/#{job_template_name}/bin/run"
        opts = { :unsetenv_others => true }

        unless File.executable?(cmd)
          raise Bosh::Agent::MessageHandlerError,
                "Job template #{job_template_name} does not have executable bin/run"
        end

        begin
          stdout, stderr, status = Open3.capture3(env, cmd, opts)
          {
            'exit_code' => status.exitstatus,
            'stdout' => stdout,
            'stderr' => stderr,
          }
        rescue Exception => e
          @logger.warn("%s\n%s" % [e.inspect, e.backtrace.join("\n")])
          raise Bosh::Agent::MessageHandlerError, e.inspect
        end
      end
    end
  end
end
