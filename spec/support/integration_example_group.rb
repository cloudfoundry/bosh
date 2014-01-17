require 'yajl'
require 'bosh/dev/sandbox/main'

module IntegrationExampleGroup
  def deploy_simple(options={})
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')

    run_bosh('create release', work_dir: TEST_RELEASE_DIR)
    run_bosh('upload release', work_dir: TEST_RELEASE_DIR)

    run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
    deploy_simple_manifest(options)
  end

  def deploy_simple_manifest(options={})
    manifest_hash = options.fetch(:manifest_hash, Bosh::Spec::Deployments.simple_manifest)
    deployment_manifest = yaml_file('simple', manifest_hash)
    run_bosh("deployment #{deployment_manifest.path}")

    no_track = options.fetch(:no_track, false)
    deploy_result = run_bosh("#{no_track ? '--no-track ' : ''}deploy")
    expect($?).to be_success

    deploy_result
  end

  def run_bosh(cmd, options = {})
    failure_expected = options.fetch(:failure_expected, false)
    work_dir = options.fetch(:work_dir, BOSH_WORK_DIR)
    Dir.chdir(work_dir) do
      command = "bosh -n -c #{BOSH_CONFIG} #{cmd}"
      output = `#{command} 2>&1`
      if $?.exitstatus != 0 && !failure_expected
        if output =~ /bosh (task \d+ --debug)/
          puts run_bosh($1, options.merge(failure_expected: true)) rescue nil
        end
        raise "ERROR: #{command} failed with #{output}"
      end
      output
    end
  end

  def current_sandbox
    @current_sandbox = Thread.current[:sandbox] || Bosh::Dev::Sandbox::Main.new
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
    expect(format_output(run_bosh(cmd, :failure_expected => true))).
      to eq(format_output(expected_output))
  end

  def get_vms
    output = run_bosh('vms --details')
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
    base.before do |example|
      unless $sandbox_started
        puts 'Starting sandboxed environment for BOSH tests...'
        current_sandbox.start

        $sandbox_started = true
        at_exit do
          begin
            if $!
              status = $!.is_a?(::SystemExit) ? $!.status : 1
            else
              status = 0
            end
            puts "\n  Stopping sandboxed environment for BOSH tests..."
            current_sandbox.stop
            cleanup_bosh
          ensure
            exit status
          end
        end
      end

      unless example.metadata[:no_reset]
        desc = example ? example.metadata[:description] : ''
        current_sandbox.reset(desc)
        FileUtils.rm_rf(current_sandbox.cloud_storage_dir)
      end
    end

    base.after do |example|
      desc = example ? example.metadata[:description] : ""
      current_sandbox.save_task_logs(desc)
    end
  end
end
