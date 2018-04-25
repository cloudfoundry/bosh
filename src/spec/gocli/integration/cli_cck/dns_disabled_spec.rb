require 'spec_helper'

describe 'cli: cloudcheck', type: :integration do
  let(:manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }
  let(:director_name) { current_sandbox.director_name }
  let(:deployment_name) { manifest['name'] }
  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  context 'with dns disabled' do
    with_reset_sandbox_before_each(dns_enabled: false)

    before do
      manifest['instance_groups'][0]['persistent_disk'] = 100
      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
    end

    context 'deployment has unresponsive agents' do
      before do
        current_sandbox.cpi.kill_agents
      end

      it 'recreates unresponsive VMs without waiting for processes to start' do
        recreate_vm_without_waiting_for_process = 3
        bosh_run_cck_with_resolution(3, recreate_vm_without_waiting_for_process)
        expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
      end
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
