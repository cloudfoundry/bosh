require_relative '../shared/support/table_helpers'

module Bosh::Spec
  class BoshRunner
    include Support::TableHelpers

    def initialize(bosh_work_dir, bosh_config, agent_log_path_resolver, nats_log_path, saved_logs_path, logger)
      @bosh_work_dir = bosh_work_dir
      @bosh_config = bosh_config
      @agent_log_path_resolver = agent_log_path_resolver
      @nats_log_path = nats_log_path
      @saved_logs_path = saved_logs_path
      @logger = logger
    end

    def run(cmd, options = {})
      run_in_dir(cmd, @bosh_work_dir, options)
    end

    def run_interactively(cmd, env = {})
      Dir.chdir(@bosh_work_dir) do
        cli_options = ''
        default_ca_cert = Bosh::Dev::Sandbox::Workspace.new.asset_path("ca/certs/rootCA.pem")
        cli_options += " --ca-cert #{default_ca_cert}"

        BlueShell::Runner.run env, "gobosh --tty #{cli_options} #{cmd}" do |runner|
          yield runner
        end
      end
    end

    def reset
      FileUtils.rm_rf(@bosh_config)
    end

    def run_in_current_dir(cmd, options={})
      run_in_dir(cmd, Dir.pwd, options)
    end

    def run_in_dir(cmd, working_dir, options = {})
      failure_expected = options.fetch(:failure_expected, false)
      log_in = options.fetch(:include_credentials, true)
      user = options[:user] || 'test'
      password = options[:password] || 'test'
      cli_options = ''
      cli_options += options.fetch(:tty, true) ? ' --tty' : ''
      cli_options += " --user=#{user} --password=#{password}" if log_in
      cli_options += options.fetch(:interactive, false) ? '' : ' -n'
      cli_options += " -d #{options[:deployment_name]}" if options[:deployment_name]

      default_ca_cert = Bosh::Dev::Sandbox::Workspace.new.asset_path("ca/certs/rootCA.pem")
      cli_options += options.fetch(:ca_cert, nil) ? " --ca-cert #{options[:ca_cert]}" : " --ca-cert #{default_ca_cert}"
      cli_options += options.fetch(:json, false) ? ' --json' : ''

      command   = "gobosh #{cli_options} #{cmd}"
      @logger.info("Running ... `#{command}`")
      output    = nil
      env = options.fetch(:env, {})
      exit_code = 0

      time = Benchmark.realtime do
        output, process_status = Open3.capture2e(env, command, chdir: working_dir)
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

    def get_most_recent_task_id
      task_table = table(run('tasks --recent --json'))

      if task_table.empty?
        raise 'No tasks found!'
      end

      task_table[0]['#']
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
