module Bosh::Spec
  class BoshRunner
    def initialize(bosh_work_dir, bosh_config, agent_log_path_resolver, logger)
      @bosh_work_dir = bosh_work_dir
      @bosh_config = bosh_config
      @agent_log_path_resolver = agent_log_path_resolver
      @logger = logger
    end

    def run(cmd, options = {})
      Dir.chdir(@bosh_work_dir) { run_in_current_dir(cmd, options) }
    end

    def run_in_current_dir(cmd, options = {})
      failure_expected = options.fetch(:failure_expected, false)

      @logger.info("Running ... bosh -n #{cmd}")
      command   = "bosh -n -c #{@bosh_config} #{cmd}"
      output    = `#{command} 2>&1`
      exit_code = $?.exitstatus

      if exit_code != 0 && !failure_expected
        if output =~ /bosh (task \d+ --debug)/
          task_output = run($1, options.merge(failure_expected: true))
          output_debug_log("Director task #{$1}", task_output) rescue nil
        elsif output =~ /Task (\d+) error/
          task_output = run("task #{$1} --debug", options.merge(failure_expected: true))
          output_debug_log("Director task #{$1}", task_output) rescue nil
        end

        if output =~ /Timed out pinging to ([a-z\-\d]+) after \d+ seconds/
          agent_output = File.read(@agent_log_path_resolver.call($1)) rescue nil
          output_debug_log("Agent log #{$1}", agent_output)
        end

        raise "ERROR: #{command} failed with output:\n#{output}"
      end

      options.fetch(:return_exit_code, false) ? [output, exit_code] : output
    end

    def run_until_succeeds(cmd, options = {})
      number_of_retries = options.fetch(:number_of_retries, 10)

      output = ''
      number_of_retries.times do
        output, exit_code = run(cmd, options.merge(failure_expected: true, return_exit_code: true))
        break if exit_code.zero?
        sleep(0.5)
      end

      output
    end

    private

    DEBUG_HEADER = '*' * 20

    def output_debug_log(title, output)
      @logger.info("#{DEBUG_HEADER} start #{title} #{DEBUG_HEADER}")
      @logger.info(output)
      @logger.info("#{DEBUG_HEADER} end #{title} #{DEBUG_HEADER}")
    end
  end
end
