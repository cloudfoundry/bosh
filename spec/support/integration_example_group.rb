require 'yajl'
require 'bosh/dev/sandbox/main'

module IntegrationExampleGroup
  def logger
    @logger ||= Logger.new(STDOUT)
  end

  def target_and_login
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
  end

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

    # Hold reference to the tempfile so that it stays around
    # until the end of tests or next deploy.
    @deployment_manifest = yaml_file('simple', manifest_hash)
    run_bosh("deployment #{@deployment_manifest.path}")

    no_track = options.fetch(:no_track, false)
    output = run_bosh("#{no_track ? '--no-track ' : ''}deploy")
    expect($?).to be_success

    output
  end

  def run_bosh(cmd, options = {})
    failure_expected = options.fetch(:failure_expected, false)
    work_dir = options.fetch(:work_dir, BOSH_WORK_DIR)

    Dir.chdir(work_dir) do
      logger.info("Running ... bosh -n #{cmd}")
      command   = "bosh -n -c #{BOSH_CONFIG} #{cmd}"
      output    = `#{command} 2>&1`
      exit_code = $?.exitstatus

      if exit_code != 0 && !failure_expected
        if output =~ /bosh (task \d+ --debug)/
          logger.info(run_bosh($1, options.merge(failure_expected: true))) rescue nil
        end
        raise "ERROR: #{command} failed with #{output}"
      end

      options.fetch(:return_exit_code, false) ? [output, exit_code] : output
    end
  end

  def yaml_file(name, object)
    Tempfile.new(name).tap do |f|
      f.write(Psych.dump(object))
      f.close
    end
  end

  def spec_asset(name)
    File.expand_path("../../assets/#{name}", __FILE__)
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
end

module IntegrationSandboxHelpers
  def start_sandbox
    return if $sandbox_started
    $sandbox_started = true

    logger.info('Starting sandboxed environment for BOSH tests...')
    current_sandbox.start

    at_exit do
      begin
        status = $! ? ($!.is_a?(::SystemExit) ? $!.status : 1) : 0
        logger.info("\n  Stopping sandboxed environment for BOSH tests...")
        current_sandbox.stop
        cleanup_sandbox_dir
      ensure
        exit(status)
      end
    end
  end

  def current_sandbox
    @current_sandbox = Thread.current[:sandbox] || Bosh::Dev::Sandbox::Main.new
    Thread.current[:sandbox] = @current_sandbox
  end

  def prepare_sandbox
    cleanup_sandbox_dir
    setup_test_release_dir
    setup_bosh_work_dir
  end

  def reset_sandbox(desc)
    current_sandbox.reset(desc)
    FileUtils.rm_rf(current_sandbox.cloud_storage_dir)
  end

  private

  def setup_test_release_dir
    FileUtils.cp_r(TEST_RELEASE_TEMPLATE, TEST_RELEASE_DIR, :preserve => true)

    Dir.chdir(TEST_RELEASE_DIR) do
      ignore = %w(
        blobs
        dev-releases
        config/dev.yml
        config/private.yml
        releases/*.tgz
        dev_releases
        .dev_builds
        .final_builds/jobs/**/*.tgz
        .final_builds/packages/**/*.tgz
        blobs
        .blobs
      )

      File.open('.gitignore', 'w+') do |f|
        f.write(ignore.join("\n") + "\n")
      end

      `git init;
       git config user.name "John Doe";
       git config user.email "john.doe@example.org";
       git add .;
       git commit -m "Initial Test Commit"`
    end
  end

  def setup_bosh_work_dir
    FileUtils.cp_r(BOSH_WORK_TEMPLATE, BOSH_WORK_DIR, :preserve => true)
  end

  def cleanup_sandbox_dir
    FileUtils.rm_rf(SANDBOX_DIR)
    FileUtils.mkdir_p(SANDBOX_DIR)
  end
end

module IntegrationSandboxBeforeHelpers
  def with_reset_sandbox_before_each
    before do |example|
      prepare_sandbox
      start_sandbox
      unless example.metadata[:no_reset]
        reset_sandbox(example ? example.metadata[:description] : '')
      end
    end
  end

  def with_reset_sandbox_before_all
    # `example` is not available in before(:all)
    before(:all) do
      prepare_sandbox
      start_sandbox
      reset_sandbox('')
    end
  end
end

RSpec.configure do |config|
  config.include(IntegrationExampleGroup, type: :integration)
  config.include(IntegrationSandboxHelpers, type: :integration)
  config.extend(IntegrationSandboxBeforeHelpers, type: :integration)
end
