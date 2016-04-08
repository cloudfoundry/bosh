require 'spec_helper'

describe 'Changing cloud config', type: :integration do
  with_reset_sandbox_before_each

  before do
    target_and_login
    create_and_upload_test_release
    upload_stemcell
  end

  describe 'changing the cloud config while deploying' do
    it 'should continue to use the original cloud config when deploying a job' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1, template: 'foobar_without_packages')

      upload_cloud_config(cloud_config_hash: cloud_config)
      task_id = Bosh::Spec::DeployHelper.start_deploy(deployment_manifest)

      upload_a_different_cloud_config

      Bosh::Spec::DeployHelper.wait_for_task_to_succeed(task_id)
    end

    it 'should continue to use the original cloud config when running an errand' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      manifest_with_errand = Bosh::Spec::NetworkingManifest.errand_manifest(instances: 1, template: 'foobar_without_packages')
      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_with_errand)
      current_target = current_sandbox.director_url

      errand_succeeded = nil
      errand_thread = Thread.new do
        thread_config_path = File.join(ClientSandbox.base_dir, 'bosh_config_errand.yml')
        bosh_runner.run("target #{current_target}", config_path: thread_config_path)
        bosh_runner.run('login test test', config_path: thread_config_path)
        _, errand_succeeded = run_errand('errand_job', config_path: thread_config_path, manifest_hash: manifest_with_errand)
      end

      upload_a_different_cloud_config

      errand_thread.join
      expect(errand_succeeded).to eq(true)
    end
  end

  describe 'changing the cloud config with health monitor running', hm: true do
    before { current_sandbox.health_monitor_process.start }
    after { current_sandbox.health_monitor_process.stop }

    it 'resurrects vm with original cloud config and IP' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1, template: 'foobar_without_packages')

      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: deployment_manifest)

      original_vm = director.vm('foobar', '0')
      original_vms_output = bosh_runner.run('vms')

      upload_a_different_cloud_config

      resurrected_vm = director.kill_vm_and_wait_for_resurrection(original_vm)
      resurrected_vms_output = bosh_runner.run('vms')

      expect(original_vm.ips).to eq(resurrected_vm.ips), "Original vm IPs '#{original_vm.ips}' do not match resurrected vm IPs '#{resurrected_vm.ips}', original output: #{original_vms_output}, resurrected output: #{resurrected_vms_output}"
    end
  end

  describe 'changing the cloud config when running cck' do
    it 'recreates vm with original cloud config' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1, template: 'foobar_without_packages')

      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: deployment_manifest)

      original_vm = director.vm('foobar', '0')

      upload_a_different_cloud_config

      original_vm.kill_agent

      bosh_runner.run_interactively('cck') do |runner|
        expect(runner).to have_output '3. Recreate VM'
        runner.send_keys '3'
        expect(runner).to have_output 'yes'
        runner.send_keys 'yes'
        expect(runner).to have_output 'done'
      end

      recreated_vm = director.vm('foobar', '0')
      expect(recreated_vm.cid).to_not eq(original_vm.cid)

      expect(original_vm.ips).to eq(recreated_vm.ips)
    end
  end

  describe 'no changes' do
    context 'when redeploying a network after rename' do
      it 'should not recreate vms when there are no changes' do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        simple_manifest = Bosh::Spec::Deployments.simple_manifest

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(manifest_hash: simple_manifest)

        cloud_config_hash['networks'].first['name'] = 'b'
        cloud_config_hash['compilation']['network'] = 'b'
        simple_manifest['jobs'].first['networks'].first['name'] = 'b'

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
    new_cloud_config['resource_pools'].first['network'] = 'other'
    new_cloud_config['compilation']['network'] = 'other'
    upload_cloud_config(cloud_config_hash: new_cloud_config)
  end
end
