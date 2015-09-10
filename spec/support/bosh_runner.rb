module Bosh::Spec
  class BoshRunner
    def initialize(bosh_work_dir, bosh_config, agent_log_path_resolver, nats_log_path, saved_logs_path, logger)
      @bosh_work_dir = bosh_work_dir
      @bosh_config = bosh_config
      @agent_log_path_resolver = agent_log_path_resolver
      @nats_log_path = nats_log_path
      @saved_logs_path = saved_logs_path
      @logger = logger
    end

    def run(cmd, options = {})
      Dir.chdir(@bosh_work_dir) { run_in_current_dir(cmd, options) }
    end

    def run_interactively(cmd, env = {})
      Dir.chdir(@bosh_work_dir) do
        BlueShell::Runner.run env, "bosh -c #{@bosh_config} #{cmd}" do |runner|
          yield runner
        end
      end
    end

    def reset
      FileUtils.rm_rf(@bosh_config)
    end

    def run_in_current_dir(cmd, options = {})
      failure_expected = options.fetch(:failure_expected, false)
      interactive_mode = options.fetch(:interactive, false) ? '' : '-n'

      @logger.info("Running ... bosh #{interactive_mode} #{cmd}")
      command   = "bosh #{interactive_mode} -c #{@bosh_config} #{cmd}"
      output    = nil
      env = options.fetch(:env, {})
      exit_code = 0

      time = Benchmark.realtime do
        output, process_status = Open3.capture2e(env, command)
        exit_code = process_status.exitstatus
      end

      @logger.info "Exit code is #{exit_code}"

      @logger.info("Command took #{time} seconds")

      if exit_code != 0 && !failure_expected
        if output =~ /bosh task (\d+) --debug/ || output =~ /Task (\d+) error/
          print_task_debug_logs($1, options)
        end

        if output =~ /Timed out pinging to ([a-z\-\d]+) after \d+ seconds/
          print_agent_debug_logs($1)
        end

        raise "ERROR: #{command} failed with output:\n#{output}"
      end

      options.fetch(:return_exit_code, false) ? [output, exit_code] : output
    end

    def print_agent_debug_logs(agent_id)
      agent_output = File.read(@agent_log_path_resolver.call(agent_id)) rescue nil
      output_debug_log("Agent log #{agent_id}", agent_output)
      output_debug_log("Nats log #{agent_id}", File.read(@nats_log_path)) if File.exists?(@nats_log_path)
    end

    def print_task_debug_logs(task_id, options)
      task_output = run("task #{task_id} --debug", options.merge(failure_expected: true, return_exit_code: false))
      output_debug_log("Director task #{task_id}", task_output) rescue nil
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
      content = <<-EOF
        #{DEBUG_HEADER} start #{title} #{DEBUG_HEADER}
        #{output}
        #{DEBUG_HEADER} end #{title} #{DEBUG_HEADER}
      EOF

      FileUtils.mkdir_p(File.dirname(@saved_logs_path))
      File.open(@saved_logs_path, 'a') { |f| f.write(content) }

      @logger.info(content)
    end
  end
end
