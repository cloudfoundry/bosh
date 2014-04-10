module Bosh::Spec
  class BoshRunner
    def initialize(bosh_work_dir, bosh_config, logger)
      @bosh_work_dir = bosh_work_dir
      @bosh_config = bosh_config
      @logger = logger
    end

    def run(cmd, options = {})
      work_dir = options.fetch(:work_dir, @bosh_work_dir)

      Dir.chdir(work_dir) do
        run_thread_safe(cmd, options)
      end
    end

    def run_thread_safe(cmd, options = {})
      @logger.info("Running ... bosh -n #{cmd}")
      command   = "bosh -n -c #{@bosh_config} #{cmd}"
      output    = `#{command} 2>&1`
      exit_code = $?.exitstatus

      failure_expected = options.fetch(:failure_expected, false)
      if exit_code != 0 && !failure_expected
        if output =~ /bosh (task \d+ --debug)/
          @logger.info(
            run_thread_safe($1, options.merge(failure_expected: true))
          ) rescue nil
        end
        raise "ERROR: #{command} failed with #{output}"
      end

      options.fetch(:return_exit_code, false) ? [output, exit_code] : output
    end

    def run_until_succeeds(cmd, options = {})
      options.merge!(
        failure_expected: true,
        return_exit_code: true
      )

      number_of_retries = options.fetch(:number_of_retries, 10)
      output = ''
      number_of_retries.times do
        output, exit_code = run(cmd, options)
        break if exit_code.zero?
        sleep(0.5)
      end

      output
    end
  end
end
