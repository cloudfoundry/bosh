require 'spec_helper'

describe 'cli: cloudcheck', type: :integration do
  let(:manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }
  let(:director_name) { current_sandbox.director_name }
  let(:deployment_name) { manifest['name'] }
  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  context 'with config server enabled' do
    with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

    let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger) }
    let(:client_env) { { 'BOSH_LOG_LEVEL' => 'debug', 'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret' } }

    before do
      pending('cli2: #131927867 gocli drops the context path from director.info.auth uaa url')
      bosh_runner.run('log-out')

      config_server_helper.put_value(prepend_namespace('test_property'), 'cats are happy')

      manifest['instance_groups'][0]['persistent_disk'] = 100
      manifest['instance_groups'].first['properties'] = { 'test_property' => '((test_property))' }
      deploy_from_scratch(
        manifest_hash: manifest,
        cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config,
        include_credentials: false,
        env: client_env,
      )

      expect(runner.run('cloud-check --report', deployment_name: 'simple', env: client_env)).to match(regexp('0 problems'))
    end

    it 'resolves issues correctly and gets values from config server' do
      vm = director.instance('foobar', '0', env: client_env)

      template = vm.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('test_property=cats are happy')

      current_sandbox.cpi.kill_agents

      config_server_helper.put_value(prepend_namespace('test_property'), 'smurfs are happy')

      recreate_vm_without_waiting_for_process = 3
      bosh_run_cck_with_resolution(3, recreate_vm_without_waiting_for_process, client_env)
      expect(runner.run('cloud-check --report', deployment_name: 'simple', env: client_env)).to match(regexp('0 problems'))

      vm = director.instance('foobar', '0', env: client_env)

      template = vm.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('test_property=cats are happy')
    end
  end

  def bosh_run_cck_with_resolution(num_errors, option = 1, env = {})
    env.each do |key, value|
      ENV[key] = value
    end

    output = ''
    bosh_runner.run_interactively('cck', deployment_name: 'simple') do |runner|
      (1..num_errors).each do
        expect(runner).to have_output 'Skip for now'

        runner.send_keys option.to_s
      end

      expect(runner).to have_output 'Continue?'
      runner.send_keys 'y'

      expect(runner).to have_output 'Succeeded'
      output = runner.output
    end
    output
  end

  def scrub_text_random_ids(text)
    text.gsub(/[0-9a-f]{8}-[0-9a-f-]{27}/, 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx')
  end

  def scrub_text_disk_ids(text)
    text.gsub(/[0-9a-z]{32}/, 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
  end

  def scrub_randoms(text)
    scrub_vm_cid(scrub_index(scrub_text_disk_ids(scrub_text_random_ids(text))))
  end

  def scrub_vm_cid(text)
    text.gsub(/'\d+'/, "'xxx'")
  end

  def scrub_index(text)
    text.gsub(/\(\d+\)/, '(x)')
  end
end
