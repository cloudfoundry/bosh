require 'yaml'
require 'integration_support/main'
require 'integration_support/verify_multidigest_manager'
require 'integration_support/gnatsd_manager'

module IntegrationSupport
  module IntegrationExampleGroup
    class DeploymentFailedError < RuntimeError

    end

    class UnknownRecordTypeError < RuntimeError

    end

    def logger
      @logger ||= current_sandbox.logger
    end

    def director
      @director ||= IntegrationSupport::Director.new(
        bosh_runner,
        waiter,
        current_sandbox.agent_tmp_path,
        current_sandbox.db,
        current_sandbox.director_nats_config,
        logger,
      )
    end

    def health_monitor
      @health_monitor ||= IntegrationSupport::HealthMonitor.new(
        current_sandbox.health_monitor_process,
        logger,
      )
    end

    def bosh_runner
      @bosh_runner ||= make_a_bosh_runner
    end

    def make_a_bosh_runner(opts = {})
      IntegrationSupport::BoshCliRunner.new(
        opts.fetch(:work_dir, IntegrationSupport::ClientSandbox.bosh_work_dir),
        opts.fetch(:config_path, IntegrationSupport::ClientSandbox.bosh_config),
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
      @waiter ||= IntegrationSupport::Waiter.new(logger)
    end

    def upload_cloud_config(options = {})
      cloud_config_hash = options.fetch(:cloud_config_hash, SharedSupport::DeploymentManifestHelper.simple_cloud_config)
      cloud_config_manifest = yaml_file('simple', cloud_config_hash)
      bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}", options)
    end

    def upload_runtime_config(options = {})
      runtime_config_hash = options.fetch(:runtime_config_hash, SharedSupport::DeploymentManifestHelper.simple_runtime_config)
      name = options.fetch(:name, '')
      runtime_config_manifest = yaml_file('simple', runtime_config_hash)
      bosh_runner.run("update-runtime-config --name=#{name} #{runtime_config_manifest.path}", options)
    end

    def create_and_upload_test_release(options = {})
      create_args = options.fetch(:force, false) ? '--force' : ''
      bosh_runner.run_in_dir("create-release #{create_args}", IntegrationSupport::ClientSandbox.test_release_dir, options)
      bosh_runner.run_in_dir('upload-release', IntegrationSupport::ClientSandbox.test_release_dir, options)
    end

    def create_and_upload_links_release
      FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, IntegrationSupport::ClientSandbox.links_release_dir, preserve: true)
      bosh_runner.run_in_dir('create-release --force', IntegrationSupport::ClientSandbox.links_release_dir)
      bosh_runner.run_in_dir('upload-release', IntegrationSupport::ClientSandbox.links_release_dir)
    end

    def update_release
      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        File.open(File.join('src', 'foo'), 'w') { |f| f.write(SecureRandom.uuid) }
      end
      create_and_upload_test_release(force: true)
    end

    def upload_stemcell(options = {})
      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell.tgz')}", options)
    end

    def upload_stemcell_2(options = {})
      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell_2.tgz')}", options)
    end

    def delete_stemcell
      bosh_runner.run('delete-stemcell ubuntu-stemcell/1')
    end

    def deployment_file(manifest_hash)
      # Hold reference to the tempfile so that it stays around
      # until the end of tests or next deploy.
      yaml_file('simple', manifest_hash)
    end

    def deploy(options = {})
      cmd = options.fetch(:no_color, false) ? '--no-color ' : ''

      deployment_hash = options.fetch(:manifest_hash, SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups)
      cmd += " -d #{deployment_hash['name']}"

      cmd += ' deploy'
      cmd += options.fetch(:no_redact, false) ? ' --no-redact' : ''
      cmd += options.fetch(:recreate, false) ? ' --recreate' : ''
      cmd += options.fetch(:recreate_persistent_disks, false) ? ' --recreate-persistent-disks' : ''
      cmd += options.fetch(:dry_run, false) ? ' --dry-run' : ''
      cmd += options.fetch(:fix, false) ? ' --fix' : ''
      cmd += options.fetch(:json, false) ? ' --json' : ''

      if options[:skip_drain]
        cmd += if options[:skip_drain].is_a?(Array)
                 options[:skip_drain].map { |skip| " --skip-drain=#{skip}" }.join('')
               else
                 ' --skip-drain'
               end
      end

      cmd += if options[:manifest_file]
               " #{asset_path(options[:manifest_file])}"
             else
               " #{deployment_file(deployment_hash).path}"
             end

      bosh_runner.run(cmd, options)
    end

    def stop_job(vm_name)
      bosh_runner.run("stop -d #{SharedSupport::DeploymentManifestHelper::DEFAULT_DEPLOYMENT_NAME} #{vm_name}", {})
    end

    def isolated_stop(
      deployment: SharedSupport::DeploymentManifestHelper::DEFAULT_DEPLOYMENT_NAME,
      instance_group:,
      index: nil,
      id: nil,
      params: {}
    )
      url = "/deployments/#{deployment}/instance_groups/#{instance_group}/#{id || index}/actions/stop?#{params.to_query}"
      curl_output = bosh_runner.run("curl -X POST #{url}", json: true)
      task_id = JSON.parse(parse_blocks(curl_output)[0])['id']
      bosh_runner.run("task #{task_id}", params)
    end

    def isolated_start(
      deployment: SharedSupport::DeploymentManifestHelper::DEFAULT_DEPLOYMENT_NAME,
      instance_group:,
      index: nil,
      id: nil,
      params: {}
    )
      url = "/deployments/#{deployment}/instance_groups/#{instance_group}/#{id || index}/actions/start?#{params.to_query}"
      curl_output = bosh_runner.run("curl -X POST #{url}", json: true)
      task_id = JSON.parse(parse_blocks(curl_output)[0])['id']
      bosh_runner.run("task #{task_id}", params)
    end

    def isolated_restart(
      deployment: SharedSupport::DeploymentManifestHelper::DEFAULT_DEPLOYMENT_NAME,
      instance_group:,
      index: nil,
      id: nil,
      params: {}
    )
      url = "/deployments/#{deployment}/instance_groups/#{instance_group}/#{id || index}/actions/restart?#{params.to_query}"
      curl_output = bosh_runner.run("curl -X POST #{url}", json: true)
      task_id = JSON.parse(parse_blocks(curl_output)[0])['id']
      bosh_runner.run("task #{task_id}", params)
    end

    def isolated_recreate(
      deployment: SharedSupport::DeploymentManifestHelper::DEFAULT_DEPLOYMENT_NAME,
      instance_group:,
      index: nil,
      id: nil,
      params: {}
    )
      url = "/deployments/#{deployment}/instance_groups/#{instance_group}/#{id || index}/actions/recreate?#{params.to_query}"
      curl_output = bosh_runner.run("curl -X POST #{url}", json: true)
      task_id = JSON.parse(parse_blocks(curl_output)[0])['id']
      bosh_runner.run("task #{task_id}", params)
    end

    def orphaned_disks
      table(bosh_runner.run('disks -o', json: true))
    end

    def deploy_from_scratch(options = {})
      prepare_for_deploy(options)
      deploy_simple_manifest(options)
    end

    def prepare_for_deploy(options = {})
      create_and_upload_test_release(options)
      upload_stemcell(options)
      upload_cloud_config(options) unless options[:legacy]
      upload_runtime_config(options) if options[:runtime_config_hash]
    end

    def deploy_simple_manifest(options = {})
      return_exit_code = options.fetch(:return_exit_code, false)

      output, exit_code = deploy(options.merge(return_exit_code: true))

      if exit_code != 0 && !options.fetch(:failure_expected, false)
        raise DeploymentFailedError, "Deploy failed. Exited #{exit_code}: #{output}"
      end

      return_exit_code ? [output, exit_code] : output
    end

    def run_errand(errand_job_name, options = {})
      failure_expected = options.fetch(:failure_expected, true)
      output, exit_code = bosh_runner.run(
        "run-errand #{errand_job_name}",
        options.merge(return_exit_code: true, failure_expected: failure_expected),
      )
      [output, exit_code.zero?]
    end

    def yaml_file(name, object)
      FileUtils.mkdir_p(IntegrationSupport::ClientSandbox.manifests_dir)
      file_path = File.join(IntegrationSupport::ClientSandbox.manifests_dir, "#{name}-#{SecureRandom.uuid}")
      File.open(file_path, 'w') do |f|
        f.write(Psych.dump(object))
        f
      end
    end

    def asset_path(name)
      File.expand_path(File.join(ASSETS_DIR, name), __FILE__)
    end

    def regexp(string)
      Regexp.compile(Regexp.escape(string))
    end

    def scrub_random_ids(bosh_output)
      sub_in_records(bosh_output, /[0-9a-f]{8}-[0-9a-f-]{27}/, 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx')
    end

    def scrub_event_time(bosh_output)
      sub_in_records(
        bosh_output,
        /[A-Za-z]{3} [A-Za-z]{3}\s{1,2}[0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC [0-9]{4}/,
        'xxx xxx xx xx:xx:xx UTC xxxx',
      )
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
      output = sub_in_records(
        bosh_output,
        /[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [-+][0-9]{4}/,
        '0000-00-00 00:00:00 -0000',
      )
      sub_in_records(output, /[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC/, '0000-00-00 00:00:00 UTC')
    end

    def extract_agent_messages(nats_messages, agent_id)
      nats_messages.select do |val|
        # messages for the agent we care about
        val[0] == "agent.#{agent_id}"
      end.map do |val|
        # parse JSON payload
        JSON.parse(val[1])
      end.flat_map do |val|
        # extract method from messages that have it
        val['method'] ? [val['method']] : []
      end
    end

    def expect_table(cmd, expected, options = {})
      options[:json] = true
      expect(table(bosh_runner.run(cmd, options))).to contain_exactly(*expected)
    end

    def check_for_unknowns(instances)
      uniq_vm_names = instances.map(&:instance_group_name).uniq
      bosh_runner.print_agent_debug_logs(instances.first.agent_id) if uniq_vm_names.size == 1 && uniq_vm_names.first == 'unknown'
    end

    def expect_running_vms_with_names_and_count(
      instance_group_names_to_instance_counts,
      options = { deployment_name: SharedSupport::DeploymentManifestHelper::DEFAULT_DEPLOYMENT_NAME }
    )
      instances = director.instances(options)
      check_for_unknowns(instances)
      names = instances.map(&:instance_group_name)
      total_expected_vms = instance_group_names_to_instance_counts.values.inject(0) { |sum, count| sum + count }
      updated_vms = instances.reject { |instance| instance.vm_cid.empty? }

      expect(updated_vms.size).to(
        eq(total_expected_vms),
        "Expected #{total_expected_vms} VMs, got #{updated_vms.size}. Present were VMs with job name: #{names}",
      )

      instance_group_names_to_instance_counts.each do |instance_group_name, expected_count|
        actual_count = names.select { |name| name == instance_group_name }.size
        expect(actual_count).to(
          eq(expected_count),
          "Expected instance group #{instance_group_name} to have #{expected_count} VMs, got #{actual_count}",
        )
      end

      expect(updated_vms.map(&:last_known_state).uniq).to eq(['running'])
    end

    def expect_logs_not_to_contain(deployment_name, task_id, list_of_strings, options = {})
      debug_output = bosh_runner.run("task #{task_id} --debug", options.merge(deployment_name: deployment_name))
      cpi_output = bosh_runner.run("task #{task_id} --cpi", options.merge(deployment_name: deployment_name))
      events_output = bosh_runner.run("task #{task_id} --event", options.merge(deployment_name: deployment_name))
      result_output = bosh_runner.run("task #{task_id} --result", options.merge(deployment_name: deployment_name))

      list_of_strings.each do |token|
        expect(debug_output).to_not include(token)
        expect(cpi_output).to_not include(token)
        expect(events_output).to_not include(token)
        expect(result_output).to_not include(token)
      end
    end

    def start_deploy(manifest)
      output = deploy_simple_manifest(manifest_hash: manifest, no_track: true)

      IntegrationSupport::OutputParser.new(output).task_id('*')
    end

    def wait_for_task(task_id)
      director.task(task_id)
    end

    def wait_for_task_to_succeed(task_id)
      output, success = wait_for_task(task_id)
      raise "task failed: #{output}" unless success
      output
    end

    def with_blocking_deploy(options = {})
      manifest =
        SharedSupport::DeploymentManifestHelper.deployment_manifest(
          name: 'blocking',
          instances: 1,
          job: 'job_with_blocking_compilation',
          job_release: 'bosh-release',
        )

      output = deploy_simple_manifest(manifest_hash: manifest, no_track: true)

      task_id = IntegrationSupport::OutputParser.new(output).task_id('*')

      director.wait_for_first_available_vm

      compilation_vm = director.vms.first
      expect(compilation_vm).to_not be_nil

      yield(task_id)

      task_id
    ensure
      if compilation_vm
        compilation_vm.unblock_package

        unless options[:skip_task_wait]
          _, first_success = wait_for_task(task_id)
          expect(first_success).to eq(true)
        end
      end
    end

    private

    def sub_in_records(output, regex_pattern, replace_pattern)
      output.map do |record|
        if record.is_a?(Hash)
          record.each do |key, value|
            record[key] = value.gsub(regex_pattern, replace_pattern)
          end
          record
        elsif record.is_a?(String)
          record.gsub(regex_pattern, replace_pattern)
        else
          raise UnknownRecordTypeError, 'Unknown record type'
        end
      end
    end
  end

  module IntegrationSandboxHelpers
    def start_sandbox
      unless sandbox_started?
        at_exit do
          begin
            status = if $!
                       $!.is_a?(::SystemExit) ? $!.status : 1
                     else
                       0
                     end
            logger.info("\n  Stopping sandboxed environment for BOSH tests...")
            current_sandbox.stop
            cleanup_client_sandbox_dir
          rescue StandardError => e
            logger.error "Failed to stop sandbox! #{e.message}\n#{e.backtrace&.join("\n")}"
          ensure
            exit(status)
          end
        end
      end

      $sandbox_started = true

      logger.info('Starting sandboxed environment for BOSH tests...')
      current_sandbox.start
    end

    def reset_sandbox(example, options)
      prepare_sandbox
      reconfigure_sandbox(options)
      if !sandbox_started?
        start_sandbox
      elsif example.nil? || !example.metadata[:no_reset]
        current_sandbox.reset
      end
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
      setup_home_dir
      setup_test_release_dir
      setup_bosh_work_dir
      Thread.current[:sandbox] ||= IntegrationSupport::Main.from_env
    end

    def reconfigure_sandbox(options)
      current_sandbox.reconfigure(options)
    end

    def setup_test_release_dir(destination_dir = IntegrationSupport::ClientSandbox.test_release_dir)
      FileUtils.rm_rf(destination_dir)
      FileUtils.cp_r(TEST_RELEASE_TEMPLATE, destination_dir, preserve: true)

      final_config_path = File.join(destination_dir, 'config', 'final.yml')
      final_config = YAML.load_file(final_config_path, permitted_classes: [Symbol], aliases: true)
      final_config['blobstore']['options']['blobstore_path'] = IntegrationSupport::ClientSandbox.blobstore_dir
      File.open(final_config_path, 'w') { |file| file.write(YAML.dump(final_config)) }

      Dir.chdir(destination_dir) do
        ignore = %w[
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
      ]

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
      FileUtils.cp_r(BOSH_WORK_TEMPLATE, IntegrationSupport::ClientSandbox.bosh_work_dir, preserve: true)
    end

    def setup_home_dir
      FileUtils.mkdir_p(IntegrationSupport::ClientSandbox.home_dir)
      ENV['HOME'] = IntegrationSupport::ClientSandbox.home_dir
      `git config --global init.defaultBranch "master"`
    end

    def cleanup_client_sandbox_dir
      FileUtils.rm_rf(IntegrationSupport::ClientSandbox.base_dir)
      FileUtils.mkdir_p(IntegrationSupport::ClientSandbox.base_dir)
    end
  end

  module IntegrationSandboxBeforeHelpers
    def with_reset_sandbox_before_each(options = {})
      before do |example|
        reset_sandbox(example, options)
      end
    end

    def with_reset_sandbox_before_all(options = {})
      # `example` is not available in before(:all)
      before(:all) do
        prepare_sandbox
        reconfigure_sandbox(options) unless options.empty?
        if !sandbox_started?
          start_sandbox
        else
          current_sandbox.reset
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
end

RSpec.configure do |config|
  config.include(IntegrationSupport::IntegrationExampleGroup, type: :integration)
  config.include(IntegrationSupport::IntegrationSandboxHelpers, type: :integration)
  config.extend(IntegrationSupport::IntegrationSandboxBeforeHelpers, type: :integration)
end
