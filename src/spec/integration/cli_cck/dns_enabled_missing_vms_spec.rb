require 'spec_helper'

describe 'cli: cloudcheck', type: :integration do
  let(:manifest) { Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups }
  let(:director_name) { current_sandbox.director_name }
  let(:deployment_name) { manifest['name'] }
  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  context 'with dns enabled' do
    with_reset_sandbox_before_each

    let(:num_instances) { 3 }

    before do
      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell_with_api_version.tgz')}")
      upload_cloud_config(cloud_config_hash: Bosh::Spec::DeploymentManifestHelper.simple_cloud_config)
      create_and_upload_test_release

      manifest['instance_groups'][0]['persistent_disk'] = 100
      manifest['instance_groups'][0]['instances'] = num_instances

      deploy(manifest_hash: manifest)

      expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
    end

    context 'deployment has missing VMs' do
      before do
        current_sandbox.cpi.delete_vm(current_sandbox.cpi.vm_cids.first)
      end

      it 'automatically recreates missing VMs when cck --auto is used' do
        cloudcheck_response = bosh_runner.run('cloud-check --auto', deployment_name: 'simple')
        expect(cloudcheck_response).to match(regexp('missing.'))
        expect(cloudcheck_response).to match(regexp('Applying problem resolutions'))
        expect(cloudcheck_response).to match(regexp('Succeeded'))
        expect(cloudcheck_response).to_not match(regexp('0 problems'))
        expect(cloudcheck_response).to_not match(regexp('1: Skip for now
                                                        2: Reboot VM
                                                        3: Recreate VM using last known apply spec
                                                        4: Delete VM
                                                        5: Delete VM reference (DANGEROUS!)'))

                                                        expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
      end

      it 'provides resolution options' do
        cloudcheck_response = scrub_text_random_ids(bosh_run_cck_with_resolution(1))
        expect(cloudcheck_response).to_not match(regexp('0 problems'))
        expect(cloudcheck_response).to match(regexp('1 missing'))
        expect(cloudcheck_response).to match(/1: Skip for now
2: Recreate VM without waiting for processes to start
3: Recreate VM and wait for processes to start
4: Delete VM reference/)
      end

      it 'recreates missing VMs without waiting for processes to start' do
        recreate_vm_without_waiting_for_process = 2
        bosh_run_cck_with_resolution(1, recreate_vm_without_waiting_for_process)
        expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
      end

      it 'recreates missing VMs and wait for processes to start' do
        recreate_vm_and_wait_for_processs = 3
        bosh_run_cck_with_resolution(1, recreate_vm_and_wait_for_processs)
        expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
      end

      it 'deletes missing VM reference' do
        delete_vm_reference = 4
        pre_cck_output =
          scrub_randoms(runner.run('cloud-check --report', deployment_name: 'simple', failure_expected: true))
        expect(pre_cck_output).to include  <<~OUTPUT.strip
1  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' with cloud ID 'xxx' missing.
        OUTPUT

        bosh_run_cck_with_resolution(1, delete_vm_reference)

        post_cck_output =
          scrub_randoms(runner.run('cloud-check --report', deployment_name: 'simple', failure_expected: true))
        expect(post_cck_output).to include("missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
        expect(post_cck_output).to include('1 problems')
      end
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
