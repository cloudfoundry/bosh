require 'spec_helper'

describe 'simultaneous deploys', type: :integration do
  with_reset_sandbox_before_each

  let(:first_manifest_hash) do
    Bosh::Spec::Deployments.simple_manifest
  end

  let(:second_manifest_hash) do
    Bosh::Spec::Deployments.simple_manifest.merge('name' => 'second')
  end

  before do
    target_and_login
    create_and_upload_test_release
    upload_stemcell
  end

  def start_deploy(manifest)
    output = deploy_simple_manifest(manifest_hash: manifest, no_track: true)
    return Bosh::Spec::OutputParser.new(output).task_id('running')
  end

  def wait_for_deploy(task_id)
    output, success = director.task(task_id)
    expect(success).to(be(true), "task failed: #{output}")
  end

  context 'when there are enough IPs for two deployments' do
    it 'allocates different IP to another deploy' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      first_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'first', instances: 1)
      second_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'second', instances: 1)

      upload_cloud_config(cloud_config_hash: cloud_config)
      first_task_id = start_deploy(first_deployment_manifest)
      second_task_id = start_deploy(second_deployment_manifest)

      wait_for_deploy(first_task_id)
      wait_for_deploy(second_task_id)

      first_deployment_ips = director.vms('first').map(&:ips).flatten
      second_deployment_ips = director.vms('second').map(&:ips).flatten
      expect(first_deployment_ips + second_deployment_ips).to match_array(
          ['192.168.1.2', '192.168.1.3']
        )
    end
  end

  context 'when there are not enough IPs for two deployments' do
    it 'fails one of deploys' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      first_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'first', instances: 2)
      second_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'second', instances: 2)

      upload_cloud_config(cloud_config_hash: cloud_config)
      first_task_id = start_deploy(first_deployment_manifest)
      second_task_id = start_deploy(second_deployment_manifest)

      first_output, first_success = director.task(first_task_id)
      second_output, second_success = director.task(second_task_id)

      expect([first_success, second_success]).to match_array([true, false])
      expect(first_output + second_output).to include("asked for a dynamic IP but there were no more available")
    end
  end

  describe 'running errand during deploy' do
    it 'allocates IPs correctly for simultaneous errand run and deploy' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      manifest_with_errand = Bosh::Spec::NetworkingManifest.errand_manifest(instances: 1)
      second_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'second', instances: 1)

      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_with_errand)

      deploy_task_id = start_deploy(second_deployment_manifest)
      run_errand(manifest_with_errand, 'errand_job')
      wait_for_deploy(deploy_task_id)

      job_deployment_ips = director.vms('second').map(&:ips).flatten
      expect(job_deployment_ips.count).to eq(1)
      expect(['192.168.1.2', '192.168.1.3']).to include(job_deployment_ips.first)
    end

    it 'raise correct error message when we over allocate IPs for errand and deploy' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      manifest_with_errand = Bosh::Spec::NetworkingManifest.errand_manifest(instances: 2)
      second_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'second', instances: 2)

      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_with_errand)

      deploy_task_id = start_deploy(second_deployment_manifest)
      errand_output, errand_success = run_errand(manifest_with_errand, 'errand_job')
      deploy_output, deploy_success = director.task(deploy_task_id)

      expect([deploy_success, errand_success]).to match_array([true, false])
      expect(deploy_output + errand_output).to include("asked for a dynamic IP but there were no more available")
    end
  end
end
