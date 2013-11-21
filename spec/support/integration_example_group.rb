require 'yajl'

module IntegrationExampleGroup
  def deploy_simple(options={})
    no_track = options.fetch(:no_track, false)
    manifest_hash = options.fetch(:manifest_hash, Bosh::Spec::Deployments.simple_manifest)

    deployment_manifest = yaml_file('simple', manifest_hash)

    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')

    run_bosh('create release', work_dir: TEST_RELEASE_DIR)
    run_bosh('upload release', work_dir: TEST_RELEASE_DIR)

    run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

    run_bosh("deployment #{deployment_manifest.path}")
    deploy_result = run_bosh("#{no_track ? "--no-track " : ""}deploy")
    expect($?).to be_success
    deploy_result
  end

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

  def run_bosh(cmd, options = {})
    failure_expected = options.fetch(:failure_expected, false)
    work_dir = options.fetch(:work_dir, BOSH_WORK_DIR)
    Dir.chdir(work_dir) do
      command = "bosh -n -c #{BOSH_CONFIG} #{cmd}"
      output = `#{command} 2>&1`
      if $?.exitstatus != 0 && !failure_expected
        raise "ERROR: #{command} failed with #{output}"
      end
      output
    end
  end

  def run_bosh_cck_ignore_errors(num_errors)
    resolution_selections = "1\n"*num_errors + "yes"
    output = `echo "#{resolution_selections}" | bosh -c #{BOSH_CONFIG} cloudcheck`
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

  # forcefully suppress raising on error...caller beware
  def expect_output(cmd, expected_output)
    format_output(run_bosh(cmd, :failure_expected => true)).should == format_output(expected_output)
  end

  def get_vms
    output = run_bosh("vms --details")
    table = output.lines.grep(/\|/)

    table = table.map { |line| line.split('|').map(&:strip).reject(&:empty?) }
    headers = table.shift || []
    headers.map! do |header|
      header.downcase.tr('/ ', '_').to_sym
    end
    output = []
    table.each do |row|
      output << Hash[headers.zip(row)]
    end
    output
  end

  def wait_for_vm(name)
    5.times do
      vm = get_vms.detect { |v| v[:job_index] == name }
      return vm if vm
    end
    nil
  end

  def kill_job_agent(name)
    vm = get_vms.detect { |v| v[:job_index] == name }
    Process.kill('INT', vm[:cid].to_i)
    vm[:cid]
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

  def events(task_id)
    result = run_bosh("task #{task_id} --raw")

    event_list = []
    result.each_line do |line|
      begin
        event = Yajl::Parser.new.parse(line)
        event_list << event if event

      rescue Yajl::ParseError
      end
    end
    event_list
  end

  def start_and_finish_times_for_job_updates(task_id)
    jobs = {}
    events(task_id).select do |e|
      e['stage'] == 'Updating job' && %w(started finished).include?(e['state'])
    end.each do |e|
      jobs[e['task']] ||= {}
      jobs[e['task']][e['state']] = e['time']
    end
    jobs
  end
end
