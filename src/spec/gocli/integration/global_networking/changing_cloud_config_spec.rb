require_relative '../../spec_helper'

describe 'Changing cloud config', type: :integration do
  with_reset_sandbox_before_each

  before do
    create_and_upload_test_release
    upload_stemcell
  end

  describe 'changing the cloud config while deploying' do
    it 'should continue to use the original cloud config when deploying a job' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1, job: 'foobar_without_packages')

      upload_cloud_config(cloud_config_hash: cloud_config)
      task_id = Bosh::Spec::DeployHelper.start_deploy(deployment_manifest)

      upload_a_different_cloud_config

      Bosh::Spec::DeployHelper.wait_for_task_to_succeed(task_id)
    end

    it 'should continue to use the original cloud config when running an errand' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      manifest_with_errand = Bosh::Spec::NetworkingManifest.errand_manifest(instances: 1, job: 'foobar_without_packages')
      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_with_errand)
      current_target = current_sandbox.director_url

      errand_succeeded = nil
      errand_thread = Thread.new do
        thread_config_path = File.join(ClientSandbox.base_dir, 'bosh_config_errand.yml')
        bosh_runner.run('log-in', config: thread_config_path, log_in: true, environment_name: current_target)
        _, errand_succeeded = run_errand('errand_job', {
          config: thread_config_path,
          manifest_hash: manifest_with_errand,
          deployment_name: 'errand',
          failure_expected: false,
          environment_name: current_target
        })
      end

      upload_a_different_cloud_config

      errand_thread.join
      expect(errand_succeeded).to eq(true)
    end
  end

  describe 'changing the cloud config with health monitor running', hm: true do
    with_reset_hm_before_each

    it 'resurrects vm with original cloud config and IP' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1, job: 'foobar_without_packages')

      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: deployment_manifest)

      original_instance = director.instance('foobar', '0')
      original_vms_output = bosh_runner.run('vms', deployment_name: 'simple')

      upload_a_different_cloud_config

      resurrected_instance = director.kill_vm_and_wait_for_resurrection(original_instance)
      resurrected_vms_output = bosh_runner.run('vms', deployment_name: 'simple')

      expect(original_instance.ips).to eq(resurrected_instance.ips), "Original vm IPs '#{original_instance.ips}' do not match resurrected vm IPs '#{resurrected_instance.ips}', original output: #{original_vms_output}, resurrected output: #{resurrected_vms_output}"
    end
  end

  describe 'changing the cloud config when running cck' do
    it 'recreates vm with original cloud config' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1, job: 'foobar_without_packages')

      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: deployment_manifest)

      original_instance = director.instance('foobar', '0')

      upload_a_different_cloud_config

      original_instance.kill_agent

      bosh_runner.run_interactively('cck', deployment_name: 'simple') do |runner|
        expect(runner).to have_output '3: Recreate VM without waiting for processes to start'
        runner.send_keys '3'
        expect(runner).to have_output 'Continue?'
        runner.send_keys 'yes'
        expect(runner).to have_output 'Succeeded'
      end

      recreated_instance = director.instance('foobar', '0')
      expect(recreated_instance.vm_cid).to_not eq(original_instance.vm_cid)

      expect(original_instance.ips).to eq(recreated_instance.ips)
    end
  end

  describe 'no changes' do
    context 'when redeploying a network after rename' do
      it 'should not recreate vms when there are no changes' do
        cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
        simple_manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(manifest_hash: simple_manifest)

        cloud_config_hash['networks'].first['name'] = 'b'
        cloud_config_hash['compilation']['network'] = 'b'
        simple_manifest['instance_groups'].first['networks'].first['name'] = 'b'

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(manifest_hash: simple_manifest)

        create_vm_count = current_sandbox.cpi.invocations_for_method('create_vm').count

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(manifest_hash: simple_manifest)

        expect(current_sandbox.cpi.invocations_for_method('create_vm').count).to eq(create_vm_count)
      end
    end
  end

  def upload_a_different_cloud_config
    new_cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 0)
    new_cloud_config['networks'].first['name'] = 'other'
    new_cloud_config['vm_types'].first['network'] = 'other'
    new_cloud_config['compilation']['network'] = 'other'
    upload_cloud_config(cloud_config_hash: new_cloud_config)
  end
end
