require_relative '../shared/support/table_helpers'

module Bosh::Spec
  class BoshGoCliRunner
    include Support::TableHelpers

    def initialize(bosh_work_dir, bosh_config, agent_log_path_resolver, nats_log_path, saved_logs_path, logger, sha2)
      @bosh_work_dir = bosh_work_dir
      @bosh_config = bosh_config
      @agent_log_path_resolver = agent_log_path_resolver
      @nats_log_path = nats_log_path
      @saved_logs_path = saved_logs_path
      @logger = logger
      @sha2 = sha2
    end

    def run(cmd, options = {})
      run_in_dir(cmd, @bosh_work_dir, options)
    end

    def run_interactively(cmd, options = {})
      Dir.chdir(@bosh_work_dir) do
        options[:tty] = true
        options[:interactive] = true
        command = generate_command(cmd, options)
        @logger.info("Running ... `#{command}`")

        BlueShell::Runner.run({}, "#{command}") do |runner|
          yield runner
        end
      end
    end

    def reset
      FileUtils.rm_rf(@bosh_config)
    end

    def current_sandbox
      sandbox = Thread.current[:sandbox]
      raise "call prepare_sandbox to set up this thread's sandbox" if sandbox.nil?
      sandbox
    end

    def run_in_current_dir(cmd, options={})
      run_in_dir(cmd, Dir.pwd, options)
    end

    def run_in_dir(cmd, working_dir, options = {})
      failure_expected = options.fetch(:failure_expected, false)
      command = generate_command(cmd, options)
      @logger.info("Running ... `#{command}`")
      output    = nil
      env = options.fetch(:env, {})
      exit_code = 0

      time = Benchmark.realtime do
        Open3.popen2e(env, command, chdir: working_dir) do |stdin, stdout_and_stderr, wait_thr|
          if options.fetch(:no_track, false)
            line = "negative-ghostrider"
            start = Time.now
            loop do
              line = stdout_and_stderr.gets
              break if line =~ /Task (\d+)/
              raise 'Failed to parse task id from output within timeout' if (Time.now - start) > 20
            end
            output = line
            exit_code = 0
            begin
              Process.kill('INT', wait_thr.pid)
            rescue
              @logger.info("Failed to kill the cli in a :no-track scenario")
            end
          else
            output = stdout_and_stderr.read
            exit_code = wait_thr.value.exitstatus
          end
        end
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

    def get_most_recent_task_id
      task_table = table(run('tasks --recent --all --json'))

      if task_table.empty?
        raise 'No tasks found!'
      end

      task_table[0]['id']
    end

    private

    def generate_command(cmd, options)
      no_color = options.fetch(:no_color, false)
      log_in = options.fetch(:include_credentials, true)
      client = options[:client] || 'test'
      client_secret = options[:client_secret] || 'test'
      config = options.fetch(:config, @bosh_config)
      cli_options = ''
      cli_options += options.fetch(:tty, true) ? ' --tty' : ''
      cli_options += " --client=#{client} --client-secret=#{client_secret}" if log_in
      cli_options += options.fetch(:interactive, false) ? '' : ' -n'
      cli_options += " --no-color" if no_color
      cli_options += " -e #{options[:environment_name] || current_sandbox.director_url}"
      cli_options += " -d #{options[:deployment_name]}" if options[:deployment_name]
      cli_options += " --config #{config}"

      default_ca_cert = Bosh::Dev::Sandbox::Workspace.new.asset_path("ca/certs/rootCA.pem")
      cli_options += options.fetch(:ca_cert, nil) ? " --ca-cert #{options[:ca_cert]}" : " --ca-cert #{default_ca_cert}"
      cli_options += options.fetch(:json, false) ? ' --json' : ''
      cli_options += ' --sha2' if @sha2

      bosh_cli = ENV['BOSH_CLI'] || "gobosh"
      "#{bosh_cli} #{cli_options} #{cmd}"
    end

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
