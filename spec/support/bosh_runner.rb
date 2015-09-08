module Bosh::Spec
  class BoshRunner
    def initialize(bosh_work_dir, bosh_config, agent_log_path_resolver, nats_log_path, saved_logs_path, logger)
      @bosh_work_dir = bosh_work_dir
      @bosh_config = bosh_config
      @agent_log_path_resolver = agent_log_path_resolver
      @nats_log_path = nats_log_path
      @saved_logs_path = saved_logs_path
      @logger = logger

      bosh_base = File.expand_path('../../..', __FILE__)
      ruby_spec = YAML.load_file(File.join(bosh_base, 'release/packages/ruby/spec'))
      release_ruby = ruby_spec['files'].find { |f| f =~ /ruby-(.*).tar.gz/ }
      runner_ruby = ENV['CLI_RUBY_VERSION'] || release_ruby

      if has_chruby?
        @bosh_script = "chruby-exec #{runner_ruby} -- bundle exec bosh"
      else
        @bosh_script = "bundle exec bosh"
      end

      logger.info "Running BOSH CLI via #{@bosh_script.inspect}"
    end

    def run(cmd, options = {})
      Dir.chdir(@bosh_work_dir) { run_in_current_dir(cmd, options) }
    end

    def base_env(env = {})
      {
        'HOME' => ENV['HOME'],
        'TERM' => 'xterm-256color'
      }.merge(env)
    end

    def run_interactively(cmd, env = {})
      command = "#{@bosh_script} -c #{@bosh_config} #{cmd}"

      Dir.chdir(@bosh_work_dir) do
        Bundler.with_clean_env do
          BoshBlueShell.new(base_env(env), command, unsetenv_others: true) do |runner|
            yield runner
          end
        end
      end
    end

    def reset
      FileUtils.rm_rf(@bosh_config)
    end

    def run_in_current_dir(cmd, options = {})
      failure_expected = options.fetch(:failure_expected, false)
      interactive_mode = options.fetch(:interactive, false) ? '' : '-n'

      @logger.info("Running... bosh #{interactive_mode} #{cmd}")
      command = "#{@bosh_script} #{interactive_mode} -c #{@bosh_config} #{cmd}"
      output = nil
      env = base_env(options.fetch(:env, {}))
      exit_code = 0

      time = Benchmark.realtime do
        Bundler.with_clean_env do
          output, process_status = Open3.capture2e(env, command, unsetenv_others: true)
          exit_code = process_status.exitstatus
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

    private

    DEBUG_HEADER = '*' * 20

    def has_chruby?
      out, status = Open3.capture2e('chruby-exec --help')
      status.success?
    rescue
        false
    end

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

    # Fixes BlueShell::Runner#initialize at...
    # https://github.com/pivotal/blue-shell/blob/c1d0c1fbfb1343d68bc10eb432e98ceb49ca6c12/lib/blue-shell/runner.rb
    # TODO: pull request.
    class BoshBlueShell < BlueShell::Runner
      def initialize(*args)
        @stdout, slave = PTY.open
        system('stty raw', :in => slave)
        read, @stdin = IO.pipe

        opts = args.pop
        opts.merge!(:in => read, :out => slave, :err => slave) if opts.is_a? Hash
        args.push opts

        @pid = spawn(*args)

        @expector = BlueShell::BufferedReaderExpector.new(@stdout, ENV['DEBUG_BACON'])

        if block_given?
          yield self
        else
          wait_for_exit
        end
      end
    end
  end
end
