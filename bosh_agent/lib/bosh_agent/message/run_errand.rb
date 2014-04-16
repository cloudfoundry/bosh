require 'open3'

module Bosh::Agent
  module Message
    class RunErrand
      CANCEL_GRACE_PERIOD_SECONDS = 30

      def self.process(args)
        self.new(args).start
      end

      def self.cancel
        pid = running_errand_pid
        Process.kill('-TERM', pid) if errand_running?
        CANCEL_GRACE_PERIOD_SECONDS.times do
          break unless errand_running?
          sleep 1
        end
        Process.kill('-KILL', pid) if errand_running?
      rescue Errno::ESRCH
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

        env = { 'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => ENV['TMPDIR'] }
        cmd = "#{@base_dir}/jobs/#{job_template_name}/bin/run"
        opts = { unsetenv_others: true, pgroup: true }

        unless File.executable?(cmd)
          raise Bosh::Agent::MessageHandlerError,
                "Job template #{job_template_name} does not have executable bin/run"
        end

        begin
          stdout, stderr, status = Open3.popen3(env, cmd, opts) { |i, o, e, t|
            self.class.running_errand_pid = t.pid

            out_reader = Thread.new { o.read }
            err_reader = Thread.new { e.read }

            i.close

            [out_reader.value, err_reader.value, t.value]
          }
          self.class.running_errand_pid = nil

          {
            'exit_code' => extract_status_code(status),
            'stdout' => stdout,
            'stderr' => stderr,
          }
        rescue Exception => e
          @logger.warn("%s\n%s" % [e.inspect, e.backtrace.join("\n")])
          raise Bosh::Agent::MessageHandlerError, e.inspect
        end
      end

      def extract_status_code(status)
        status.exitstatus || (status.termsig + 128)
      end

      class << self
        attr_accessor :running_errand_pid
      end

      def self.errand_running?
        return false unless running_errand_pid
        Process.kill(0, running_errand_pid)
        true
      rescue Errno::ESRCH
        false
      end
    end
  end
end
