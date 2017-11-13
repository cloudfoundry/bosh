require_relative '../../spec_helper'

describe 'simultaneous deploys', type: :integration do
  include Bosh::Spec::BlockingDeployHelper
  with_reset_sandbox_before_each

  let(:first_manifest_hash) do
    Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
  end

  let(:second_manifest_hash) do
    Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.merge('name' => 'second')
  end

  before do
    create_and_upload_test_release
    upload_stemcell
  end

  context 'when there are enough IPs for two deployments' do
    it 'allocates different IP to another deploy' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 6)
      first_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'first', instances: 1, job: 'foobar_without_packages')
      second_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'second', instances: 1, job: 'foobar_without_packages')

      upload_cloud_config(cloud_config_hash: cloud_config)
      first_task_id = Bosh::Spec::DeployHelper.start_deploy(first_deployment_manifest)
      second_task_id = Bosh::Spec::DeployHelper.start_deploy(second_deployment_manifest)

      Bosh::Spec::DeployHelper.wait_for_task_to_succeed(first_task_id)
      Bosh::Spec::DeployHelper.wait_for_task_to_succeed(second_task_id)

      first_deployment_ips = director.instances(deployment_name: 'first').map(&:ips).flatten
      second_deployment_ips = director.instances(deployment_name: 'second').map(&:ips).flatten
      expect(first_deployment_ips + second_deployment_ips).to match_array(
          ['192.168.1.2', '192.168.1.3']
        )
    end
  end

  context 'when there are not enough IPs for compilation for two deployments' do
    it 'fails one of deploys' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 3)
      upload_cloud_config(cloud_config_hash: cloud_config)

      with_blocking_deploy do
        deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'second', instances: 1)
        output = deploy_simple_manifest(manifest_hash: deployment_manifest, failure_expected: true)
        expect(output).to match(/Failed to reserve IP for 'compilation-.*' for manual network 'a': no more available/)
      end
    end
  end

  context 'when there are not enough IPs for two deployments' do
    it 'fails one of deploys' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      first_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'first', instances: 2, job: 'foobar_without_packages')
      second_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'second', instances: 2, job: 'foobar_without_packages')

      upload_cloud_config(cloud_config_hash: cloud_config)
      first_task_id = Bosh::Spec::DeployHelper.start_deploy(first_deployment_manifest)
      second_task_id = Bosh::Spec::DeployHelper.start_deploy(second_deployment_manifest)

      first_output, first_success = Bosh::Spec::DeployHelper.wait_for_task(first_task_id)
      second_output, second_success = Bosh::Spec::DeployHelper.wait_for_task(second_task_id)

      expect([first_success, second_success]).to match_array([true, false])
      expect(first_output + second_output).to include('no more available')
    end
  end

  describe 'running errand during deploy' do
    it 'allocates IPs correctly for simultaneous errand run and deploy' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      manifest_with_errand = Bosh::Spec::NetworkingManifest.errand_manifest(instances: 1)
      second_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'second', instances: 1, job: 'foobar_without_packages')

      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_with_errand)

      deploy_task_id = Bosh::Spec::DeployHelper.start_deploy(second_deployment_manifest)
      run_errand('errand_job', manifest_hash: manifest_with_errand)
      Bosh::Spec::DeployHelper.wait_for_task_to_succeed(deploy_task_id)

      job_deployment_ips = director.instances(deployment_name: 'second').map(&:ips).flatten
      expect(job_deployment_ips.count).to eq(1)
      expect(['192.168.1.2', '192.168.1.3']).to include(job_deployment_ips.first)
    end

    it 'raises correct error message when we do not have enough IPs for the errand and the deploy' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      manifest_with_errand = Bosh::Spec::NetworkingManifest.errand_manifest(instances: 2, job: 'errand_without_package')
      second_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'second', instances: 2, job: 'foobar_without_packages')

      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_with_errand)

      deploy_task_id = Bosh::Spec::DeployHelper.start_deploy(second_deployment_manifest)
      errand_output, errand_success = run_errand('errand_job', deployment_name: 'errand', manifest_hash: manifest_with_errand)
      deploy_output, deploy_success = Bosh::Spec::DeployHelper.wait_for_task(deploy_task_id)

      expect([deploy_success, errand_success]).to match_array([true, false]), "\nerrand output:\n#{errand_output}\n\ndeploy output:\n#{deploy_output}\n"
      expect(deploy_output + errand_output).to include('no more available')
    end
  end

  describe 'running two errands' do
    it 'allocates IPs correctly for simultaneous errand runs' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      first_errand_manifest = Bosh::Spec::NetworkingManifest.errand_manifest(name: 'first-errand', instances: 1)
      second_errand_manifest = Bosh::Spec::NetworkingManifest.errand_manifest(name: 'second-errand',instances: 1)

      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: first_errand_manifest)
      deploy_simple_manifest(manifest_hash: second_errand_manifest)

      first_errand_runner, second_errand_runner = make_independent_bosh_runners

      first_errand_thread, first_result = run_errand_in_thread(first_errand_manifest, first_errand_runner)
      second_errand_thread, second_result = run_errand_in_thread(second_errand_manifest, second_errand_runner)

      first_errand_thread.join
      second_errand_thread.join

      expect(first_result.fetch(:exit_code)).to eq(0), "Failed to run first errand: #{first_result.fetch(:output)}"
      expect(second_result.fetch(:exit_code)).to eq(0), "Failed to run second errand: #{second_result.fetch(:output)}"
    end

    it 'raises correct error message when we do not have enough IPs for the errands' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      first_errand_manifest = Bosh::Spec::NetworkingManifest.errand_manifest(name: 'first-errand', instances: 1)
      second_errand_manifest = Bosh::Spec::NetworkingManifest.errand_manifest(name: 'second-errand',instances: 1)

      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: first_errand_manifest)
      deploy_simple_manifest(manifest_hash: second_errand_manifest)

      first_errand_runner, second_errand_runner = make_independent_bosh_runners

      first_errand_thread, first_result = run_errand_in_thread(first_errand_manifest, first_errand_runner)
      second_errand_thread, second_result = run_errand_in_thread(second_errand_manifest, second_errand_runner)

      first_errand_thread.join
      second_errand_thread.join

      expect([first_result.fetch(:exit_code), second_result.fetch(:exit_code)]).to match_array([1, 0])
      expect(first_result.fetch(:output)+ second_result.fetch(:output)).to include('no more available')
    end

    def run_errand_in_thread(errand_manifest, errand_runner)
      errand_result = {}
      current_target = current_sandbox.director_url
      errand_thread = Thread.new do
        output, exit_code = errand_runner.run("run-errand errand_job", deployment_name: errand_manifest['name'], return_exit_code: true, failure_expected: true, environment_name: current_target)
        errand_result.merge!(
          output: output,
          exit_code: exit_code
        )
      end
      return errand_thread, errand_result
    end

    def make_independent_bosh_runners
      FileUtils.touch(ClientSandbox.bosh_config)
      first_config_path = File.join(ClientSandbox.base_dir, 'first_config.yml')
      FileUtils.copy(ClientSandbox.bosh_config, first_config_path)
      second_config_path = File.join(ClientSandbox.base_dir, 'second_config.yml')
      FileUtils.copy(ClientSandbox.bosh_config, second_config_path)
      first_errand_runner = make_a_bosh_runner(config_path: first_config_path)
      second_errand_runner = make_a_bosh_runner(config_path: second_config_path)
      return first_errand_runner, second_errand_runner
    end
  end
end
