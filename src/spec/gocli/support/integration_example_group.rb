require 'yaml'
require 'yajl'
require 'bosh/dev/sandbox/main'
require 'bosh/dev/legacy_agent_manager'
require 'bosh/dev/verify_multidigest_manager'

module IntegrationExampleGroup
  def logger
    @logger ||= current_sandbox.logger
  end

  def director
    @director ||= Bosh::Spec::Director.new(
      bosh_runner,
      waiter,
      current_sandbox.agent_tmp_path,
      current_sandbox.nats_port,
      current_sandbox.db,
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
    @bosh_runner ||= make_a_bosh_runner
  end

  def make_a_bosh_runner(opts={})
    Bosh::Spec::BoshGoCliRunner.new(
      opts.fetch(:work_dir, ClientSandbox.bosh_work_dir),
      opts.fetch(:config_path, ClientSandbox.bosh_config),
      current_sandbox.cpi.method(:agent_log_path),
      current_sandbox.nats_log_path,
      current_sandbox.saved_logs_path,
      logger,
      ENV['SHA2_MODE'] == 'true',
    )
  end

  def bosh_runner_in_work_dir(work_dir)
    make_a_bosh_runner(work_dir: work_dir)
  end

  def waiter
    @waiter ||= Bosh::Spec::Waiter.new(logger)
  end

  def upload_cloud_config(options={})
    cloud_config_hash = options.fetch(:cloud_config_hash, Bosh::Spec::Deployments.simple_cloud_config)
    cloud_config_manifest = yaml_file('simple', cloud_config_hash)
    bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}", options)
  end

  def upload_runtime_config(options={})
    runtime_config_hash = options.fetch(:runtime_config_hash, Bosh::Spec::Deployments.simple_runtime_config)
    runtime_config_manifest = yaml_file('simple', runtime_config_hash)
    bosh_runner.run("update-runtime-config #{runtime_config_manifest.path}", options)
  end

  def create_and_upload_test_release(options={})
    create_args = options.fetch(:force, false) ? '--force' : ''
    bosh_runner.run_in_dir("create-release #{create_args}", ClientSandbox.test_release_dir, options)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.test_release_dir, options)
  end

  def update_release
    Dir.chdir(ClientSandbox.test_release_dir) do
      File.open(File.join('src', 'foo'), 'w') { |f| f.write(SecureRandom.uuid) }
    end
    create_and_upload_test_release(force: true)
  end

  def upload_stemcell(options={})
    bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}", options)
  end

  def upload_stemcell_2(options={})
    bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell_2.tgz')}", options)
  end

  def delete_stemcell
    bosh_runner.run('delete-stemcell ubuntu-stemcell/1')
  end

  def deployment_file(manifest_hash)
    # Hold reference to the tempfile so that it stays around
    # until the end of tests or next deploy.
    yaml_file('simple', manifest_hash)
  end

  def deploy(options={})
    cmd = options.fetch(:no_color, false) ? '--no-color ' : ''

    deployment_hash = options.fetch(:manifest_hash, Bosh::Spec::Deployments.simple_manifest)
    cmd += " -d #{deployment_hash['name']}"

    cmd += ' deploy'
    cmd += options.fetch(:no_redact, false) ? ' --no-redact' : ''
    cmd += options.fetch(:recreate, false) ? ' --recreate' : ''
    cmd += options.fetch(:dry_run, false) ? ' --dry-run' : ''
    cmd += options.fetch(:fix, false) ? ' --fix' : ''
    cmd += options.fetch(:json, false) ? ' --json' : ''

    if options[:skip_drain]
      if options[:skip_drain].is_a?(Array)
        cmd += options[:skip_drain].map { |skip| " --skip-drain=#{skip}" }.join('')
      else
        cmd += " --skip-drain"
      end
    end

    cmd += " #{deployment_file(deployment_hash).path}"

    bosh_runner.run(cmd, options)
  end

  def stop_job(vm_name)
    bosh_runner.run("stop -d #{Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME} #{vm_name}", {})
  end

  def deploy_from_scratch(options={})
    prepare_for_deploy(options)
    deploy_simple_manifest(options)
  end

  def prepare_for_deploy(options={})
    create_and_upload_test_release(options)
    upload_stemcell(options)
    upload_cloud_config(options) unless options[:legacy]
    if options[:runtime_config_hash]
      upload_runtime_config(options)
    end
  end

  def deploy_simple_manifest(options={})
    return_exit_code = options.fetch(:return_exit_code, false)

    output, exit_code = deploy(options.merge({return_exit_code: true}))

    if exit_code != 0 && !options.fetch(:failure_expected, false)
      raise "Deploy failed. Exited #{exit_code}: #{output}"
    end

    return_exit_code ? [output, exit_code] : output
  end

  def run_errand(errand_job_name, options={})
    failure_expected = options.fetch(:failure_expected, true)
    output, exit_code = bosh_runner.run(
      "run-errand #{errand_job_name}",
      options.merge({return_exit_code: true, failure_expected: failure_expected})
    )
    return output, exit_code == 0
  end

  def yaml_file(name, object)
    FileUtils.mkdir_p(ClientSandbox.manifests_dir)
    file_path = File.join(ClientSandbox.manifests_dir, "#{name}-#{SecureRandom.uuid}")
    File.open(file_path, 'w') { |f| f.write(Psych.dump(object)); f }
  end

  def spec_asset(name)
    File.expand_path("#{ASSETS_DIR}/#{name}", __FILE__)
  end

  def regexp(string)
    Regexp.compile(Regexp.escape(string))
  end

  def scrub_random_ids(bosh_output)
    sub_in_records(bosh_output, /[0-9a-f]{8}-[0-9a-f-]{27}/, 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx')
  end

  def scrub_event_time(bosh_output)
    sub_in_records(bosh_output, /[A-Za-z]{3} [A-Za-z]{3}\s{1,2}[0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC [0-9]{4}/, 'xxx xxx xx xx:xx:xx UTC xxxx')
  end

  def scrub_event_parent_ids(bosh_output)
    sub_in_records(bosh_output, /[0-9]{1,3} <- [0-9]{1,3} [ ]{0,}/, 'x <- x ')
  end

  def scrub_event_ids(bosh_output)
    sub_in_records(bosh_output, /[ ][0-9]{1,3} [ ]{0,}/, ' x      ')
  end

  def scrub_event_specific(bosh_output)
    bosh_output_after_ids = scrub_random_ids(bosh_output)
    bosh_output_after_cids = scrub_random_cids(bosh_output_after_ids)
    bosh_output_after_time = scrub_event_time(bosh_output_after_cids)
    bosh_output_after_parent_ids = scrub_event_parent_ids(bosh_output_after_time)
    scrub_event_ids(bosh_output_after_parent_ids)
  end

  def scrub_random_cids(bosh_output)
    sub_in_records(bosh_output, /[0-9a-f]{32}/, 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
  end

  def cid_from(bosh_output)
    bosh_output[/[0-9a-f]{32}/, 0]
  end

  def scrub_time(bosh_output)
    output = sub_in_records(bosh_output, /[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [-+][0-9]{4}/, '0000-00-00 00:00:00 -0000')
    sub_in_records(output, /[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC/, '0000-00-00 00:00:00 UTC')
  end

  def extract_agent_messages(nats_messages, agent_id)
    nats_messages.select { |val|
      # messages for the agent we care about
      val[0] == "agent.#{agent_id}"
    }.map { |val|
      # parse JSON payload
      JSON.parse(val[1])
    }.flat_map { |val|
      # extract method from messages that have it
      val['method'] ? [val['method']] : []
    }
  end

  def expect_table(cmd, expected)
    expect(table(bosh_runner.run(cmd, json: true))).to eq(expected)
  end

  def check_for_unknowns(vms)
    uniq_vm_names = vms.map(&:job_name).uniq
    if uniq_vm_names.size == 1 && uniq_vm_names.first == 'unknown'
      bosh_runner.print_agent_debug_logs(vms.first.agent_id)
    end
  end

  def expect_running_vms_with_names_and_count(job_names_to_vm_counts, options={deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME})
    vms = director.instances(options)
    check_for_unknowns(vms)
    names = vms.map(&:job_name)
    total_expected_vms = job_names_to_vm_counts.values.inject(0) {|sum, count| sum + count}
    updated_vms = vms.select { |instance| !instance.vm_cid.empty? }

    expect(updated_vms.size).to eq(total_expected_vms), "Expected #{total_expected_vms} VMs, got #{updated_vms.size}. Present were VMs with job name: #{names}"

    job_names_to_vm_counts.each do |job_name, expected_count|
      actual_count = names.select { |name| name == job_name }.size
      expect(actual_count).to eq(expected_count), "Expected job #{job_name} to have #{expected_count} VMs, got #{actual_count}"
    end

    expect(updated_vms.map(&:last_known_state).uniq).to eq(['running'])
  end

  def get_legacy_agent_path(legacy_agent_name)
    Bosh::Dev::LegacyAgentManager.generate_executable_full_path(legacy_agent_name)
  end

  private

  def sub_in_records(output, regex_pattern, replace_pattern)
    output.map do |record|
      if record.kind_of?(Hash)
        record.each do |key, value|
          record[key] = value.gsub(regex_pattern, replace_pattern)
        end
        record
      elsif record.kind_of?(String)
        record.gsub(regex_pattern, replace_pattern)
      else
        raise 'Unknown record type'
      end
    end
  end
end

module IntegrationSandboxHelpers
  def start_sandbox
    unless sandbox_started?
      at_exit do
        begin
          status = $! ? ($!.is_a?(::SystemExit) ? $!.status : 1) : 0
          logger.info("\n  Stopping sandboxed environment for BOSH tests...")
          current_sandbox.stop
          cleanup_client_sandbox_dir
        rescue => e
          logger.error "Failed to stop sandbox! #{e.message}\n#{e.backtrace.join("\n")}"
        ensure
          exit(status)
        end
      end
    end

    $sandbox_started = true

    logger.info('Starting sandboxed environment for BOSH tests...')
    current_sandbox.start
  end

  def sandbox_started?
    !!$sandbox_started
  end

  def current_sandbox
    sandbox = Thread.current[:sandbox]
    raise "call prepare_sandbox to set up this thread's sandbox" if sandbox.nil?
    sandbox
  end

  def prepare_sandbox
    cleanup_client_sandbox_dir
    setup_test_release_dir
    setup_bosh_work_dir
    setup_home_dir
    Thread.current[:sandbox] ||= Bosh::Dev::Sandbox::Main.from_env
  end

  def reconfigure_sandbox(options)
    current_sandbox.reconfigure(options)
  end

  def reset_sandbox
    current_sandbox.reset
  end

  def setup_test_release_dir(destination_dir = ClientSandbox.test_release_dir)
    FileUtils.rm_rf(destination_dir)
    FileUtils.cp_r(TEST_RELEASE_TEMPLATE, destination_dir, :preserve => true)

    final_config_path = File.join(destination_dir, 'config', 'final.yml')
    final_config = YAML.load_file(final_config_path)
    final_config['blobstore']['options']['blobstore_path'] = ClientSandbox.blobstore_dir
    File.open(final_config_path, 'w') { |file| file.write(YAML.dump(final_config)) }

    Dir.chdir(destination_dir) do
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
        .DS_Store
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

  private

  def setup_bosh_work_dir
    FileUtils.cp_r(BOSH_WORK_TEMPLATE, ClientSandbox.bosh_work_dir, :preserve => true)
  end

  def setup_home_dir
    FileUtils.mkdir_p(ClientSandbox.home_dir)
    ENV['HOME'] = ClientSandbox.home_dir
  end

  def cleanup_client_sandbox_dir
    FileUtils.rm_rf(ClientSandbox.base_dir)
    FileUtils.mkdir_p(ClientSandbox.base_dir)
  end
end

module IntegrationSandboxBeforeHelpers
  def with_reset_sandbox_before_each(options={})
    before do |example|
      prepare_sandbox
      reconfigure_sandbox(options)
      if !sandbox_started?
        start_sandbox
      elsif !example.metadata[:no_reset]
        reset_sandbox
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
        reset_sandbox
      end
    end
  end

  def with_reset_hm_before_each
    before do
      current_sandbox.reconfigure_health_monitor
    end
    after do
      current_sandbox.health_monitor_process.stop
    end
  end
end

RSpec.configure do |config|
  config.include(IntegrationExampleGroup, type: :integration)
  config.include(IntegrationExampleGroup, type: :upgrade)
  config.include(IntegrationSandboxHelpers, type: :integration)
  config.include(IntegrationSandboxHelpers, type: :upgrade)
  config.extend(IntegrationSandboxBeforeHelpers, type: :integration)
  config.extend(IntegrationSandboxBeforeHelpers, type: :upgrade)
end
