module IntegrationExampleGroup
  def start_sandbox
    puts "Starting sandboxed environment for BOSH tests..."
    current_sandbox.start
  end

  def stop_sandbox
    puts "\n  Stopping sandboxed environment for BOSH tests..."
    current_sandbox.stop
    cleanup_bosh
  end

  def reset_sandbox(example)
    desc = example ? example.example.metadata[:description] : ""
    current_sandbox.reset(desc)
  end

  def run_bosh(cmd, work_dir = nil, options = {})
    failure_expected = options.fetch(:failure_expected, false)
    Dir.chdir(work_dir || BOSH_WORK_DIR) do
      output = `bosh -n -c #{BOSH_CONFIG} -C #{BOSH_CACHE_DIR} #{cmd} 2>&1`
      if $?.exitstatus != 0 && !failure_expected
        puts output
      end
      output
    end
  end

  def run_bosh_cck_ignore_errors(num_errors)
    resolution_selections = "1\n"*num_errors + "yes"
    output = `echo "#{resolution_selections}" | bosh -c #{BOSH_CONFIG} -C #{BOSH_CACHE_DIR} cloudcheck`
    if $?.exitstatus != 0
      puts output
    end
    output
  end

  def current_sandbox
    @current_sandbox = Thread.current[:sandbox] || Bosh::Spec::Sandbox.new
    Thread.current[:sandbox] = @current_sandbox
  end

  def regexp(string)
    Regexp.compile(Regexp.escape(string))
  end

  def format_output(out)
    out.gsub(/^\s*/, '').gsub(/\s*$/, '')
  end

  def expect_output(cmd, expected_output)
    format_output(run_bosh(cmd)).should == format_output(expected_output)
  end

  def self.included(base)
    base.before(:each) do |example|
      unless $sandbox_started
        start_sandbox
        $sandbox_started = true
        at_exit do
          begin
            if $!
              status = $!.is_a?(::SystemExit) ? $!.status : 1
            else
              status = 0
            end
            stop_sandbox
          ensure
            exit status
          end
        end
      end

      reset_sandbox(example) unless example.example.metadata[:no_reset]
    end

    base.after(:each) do |example|
      desc = example ? example.example.metadata[:description] : ""
      current_sandbox.save_task_logs(desc)
      FileUtils.rm_rf(current_sandbox.cloud_storage_dir)
    end
  end
end
