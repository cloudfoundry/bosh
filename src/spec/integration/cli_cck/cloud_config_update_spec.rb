require 'spec_helper'

describe 'cli: cloudcheck', type: :integration do
  let(:manifest) { SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups }
  let(:director_name) { current_sandbox.director_name }
  let(:deployment_name) { manifest['name'] }
  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  context 'when cloud config is updated after deploying' do
    with_reset_sandbox_before_each
    let(:cloud_config_hash) { SharedSupport::DeploymentManifestHelper.simple_cloud_config }

    before do
      manifest['instance_groups'][0]['instances'] = 1
      manifest['instance_groups'][0]['networks'].first['static_ips'] = ['192.168.1.10']
      create_and_upload_test_release
      upload_stemcell
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest)

      expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
    end

    it 'recreates VMs with the non-updated cloud config' do
      current_sandbox.cpi.delete_vm(current_sandbox.cpi.vm_cids.first)
      cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.20']
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      bosh_run_cck_with_resolution(1, 3)
      expect(director.vms.first.ips).to eq(['192.168.1.10'])
    end
  end

  def bosh_run_cck_with_resolution(num_errors, option = 1)
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
