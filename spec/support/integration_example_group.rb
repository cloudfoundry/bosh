require 'yaml'
require 'yajl'
require 'bosh/dev/sandbox/main'

module IntegrationExampleGroup
  def logger
    @logger ||= Logger.new(STDOUT)
  end

  def director
    @director ||= Bosh::Spec::Director.new(
      bosh_runner,
      waiter,
      current_sandbox.agent_tmp_path,
      current_sandbox.nats_port,
      logger,
    )
  end

  def health_monitor
    @health_monitor ||= Bosh::Spec::HealthMonitor.new(
      current_sandbox.health_monitor_process,
      logger,
    )
  end

  def bosh_runner
    @bosh_runner ||= Bosh::Spec::BoshRunner.new(
      BOSH_WORK_DIR,
      BOSH_CONFIG,
      current_sandbox.cpi.method(:agent_log_path),
      @current_sandbox.nats_log_path,
      @current_sandbox.saved_logs_path,
      logger
    )
  end

  def bosh_runner_in_work_dir(work_dir)
    Bosh::Spec::BoshRunner.new(
      work_dir,
      BOSH_CONFIG,
      current_sandbox.cpi.method(:agent_log_path),
      @current_sandbox.nats_log_path,
      @current_sandbox.saved_logs_path,
      logger
    )
  end

  def waiter
    @waiter ||= Bosh::Spec::Waiter.new(logger)
  end

  def target_and_login
    bosh_runner.run("target #{current_sandbox.director_url}")
    bosh_runner.run('login admin admin')
  end

  def create_and_upload_test_release
    Dir.chdir(TEST_RELEASE_DIR) do
      bosh_runner.run_in_current_dir('create release')
      bosh_runner.run_in_current_dir('upload release')
    end
  end

  def upload_stemcell
    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
  end

  def set_deployment(options)
    manifest_hash = options.fetch(:manifest_hash, Bosh::Spec::Deployments.simple_manifest)

    # Hold reference to the tempfile so that it stays around
    # until the end of tests or next deploy.
    @deployment_manifest = yaml_file('simple', manifest_hash)
    bosh_runner.run("deployment #{@deployment_manifest.path}")
  end

  def deploy(options)
    no_track = options.fetch(:no_track, false)
    bosh_runner.run("#{no_track ? '--no-track ' : ''}deploy", options)
  end

  def deploy_simple(options={})
    target_and_login
    create_and_upload_test_release
    upload_stemcell
    deploy_simple_manifest(options)
  end

  def deploy_simple_manifest(options={})
    set_deployment(options)
    return_exit_code = options.fetch(:return_exit_code, false)

    output, exit_code = deploy(options.merge({return_exit_code: true}))

    expect($?.success?).to_not eq(options.fetch(:failure_expected, false))

    return_exit_code ? [output, exit_code] : output
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
    expect(format_output(bosh_runner.run(cmd, :failure_expected => true))).
      to eq(format_output(expected_output))
  end
end

module IntegrationSandboxHelpers
  def start_sandbox
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

  def sandbox_started?
    !!$sandbox_started
  end

  def current_sandbox
    @current_sandbox = Thread.current[:sandbox] || Bosh::Dev::Sandbox::Main.from_env
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

    final_config_path = File.join(TEST_RELEASE_DIR, 'config', 'final.yml')
    final_config = YAML.load_file(final_config_path)
    final_config['blobstore']['options']['blobstore_path'] = File.join(SANDBOX_DIR, 'release_blobstore')
    File.open(final_config_path, 'w') { |file| file.write(YAML.dump(final_config)) }

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
      if !sandbox_started?
        start_sandbox
      elsif !example.metadata[:no_reset]
        reset_sandbox(example ? example.metadata[:description] : '')
      end
    end
  end

  def with_reset_sandbox_before_all
    # `example` is not available in before(:all)
    before(:all) do
      prepare_sandbox
      if !sandbox_started?
        start_sandbox
      else
        reset_sandbox('')
      end
    end
  end
end

RSpec.configure do |config|
  config.include(IntegrationExampleGroup, type: :integration)
  config.include(IntegrationSandboxHelpers, type: :integration)
  config.extend(IntegrationSandboxBeforeHelpers, type: :integration)
end
