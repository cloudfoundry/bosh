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

    def run_interactively(cmd, options={})
      Dir.chdir(@bosh_work_dir) do
        command   = "bosh -c #{@bosh_config} #{cmd}"
        InteractiveCommandRunner.new(@logger).run(command) do |terminal|
          yield terminal
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
      time      = Benchmark.realtime { output = `#{command} 2>&1` }
      @logger.info("Command took #{time} seconds")
      exit_code = $?.exitstatus

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

    class InteractiveCommandRunner
      def initialize(logger)
        @logger = logger
      end

      def run(command)
        @logger.info "Running '#{command}'"
        stdin, stdout, stderr, wait_thr = Open3.popen3(command)
        stdout_output = StringIO.new("")
        stderr_output = StringIO.new("")
        outthread = consume_pipe_in_thread(stdout, stdout_output)
        errthread = consume_pipe_in_thread(stderr, stderr_output)

        command_terminal = InteractiveCommandTerminal.new(stdin, stdout_output, stderr_output)

        yield command_terminal

        wait_for_exit(wait_thr, stdout_output, stderr_output)
        stdout_output.string
      ensure
        outthread.kill
        errthread.kill
        wait_thr.kill
      end

      private

      def consume_pipe_in_thread(in_pipe, out_pipe)
        Thread.new do
          IO.select([in_pipe]) #waits for the pipe to be readable
          while !in_pipe.eof?
            char = in_pipe.getc
            out_pipe.print(char)
          end
        end
      end

      def wait_for_exit(wait_thr, stdout_output, stderr_output)
        timeout = 5
        Timeout.timeout(timeout) do
          wait_thr.value
        end
      rescue Timeout::Error
        wait_thr.kill
        raise <<-Error
Timed out waiting for command to finish (took longer than #{timeout} seconds)
Out: #{stdout_output.string}
Err: #{stderr_output.string}
        Error
      end
    end

    class InteractiveCommandTerminal
      def initialize(stdin, stdout, stderr)
        @stdin, @stdout, @stderr = stdin, stdout, stderr
      end

      def wait_for_output(desired_output, options={})
        timeout = options.fetch(:timeout, 30)

        Timeout.timeout(timeout) do
          loop do
            break if @stdout.string.match(desired_output)
            sleep 0.1
          end
        end

      rescue Timeout::Error
        raise <<-Error
Timed out waiting for output: '#{desired_output}' (took longer than #{timeout} seconds)
Out: #{@stdout.string}
Err: #{@stderr.string}
        Error
      end

      def send_input(input)
        @stdin.puts(input)
      end
    end
  end
end
