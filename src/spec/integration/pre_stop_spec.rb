require 'spec_helper'

describe 'pre-stop', type: :integration do
  let(:deployment_name) { 'simple' }

  with_reset_sandbox_before_each

  let(:cloud_config_hash) do
    Bosh::Spec::Deployments.simple_cloud_config
  end

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['jobs'].first['name'] = 'bazquux'
    manifest_hash['releases'].first['version'] = 'latest'
    manifest_hash['instance_groups'].first['instances'] = 1
    manifest_hash['instance_groups'].first['name'] = 'bazquux'
    manifest_hash
  end

  describe 'when pre-stop script is present' do
    let(:instance) { director.instance('bazquux', '0') }
    let(:log_path) { "#{current_sandbox.agent_tmp_path}/agent-base-dir-#{instance.agent_id}/data/sys/log" }

    it 'runs the pre-stop script on a job if pre-stop script is present' do
      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
      bosh_runner.run('stop bazquux/0', deployment_name: 'simple')

      pre_stop_log = File.read(File.join(log_path, 'bazquux/pre-stop.stdout.log'))
      expect(pre_stop_log).to include('Running pre-stop')
    end

    describe 'NEXT_STATE env vars', run_script_env: true do
      it 'passes BOSH_VM_NEXT_STATE when deleting the vm' do
        manifest_hash['instance_groups'].first['jobs'].first['properties']['fail_on_pre_stop'] = true
        deploy_from_scratch(
          cloud_config_hash: cloud_config_hash,
          manifest_hash: manifest_hash,
        )

        bosh_runner.run('stop --hard bazquux/0', deployment_name: 'simple', failure_expected: true)
        pre_stop_log = File.read(File.join(log_path, 'bazquux/pre-stop.stdout.log'))
        expect(pre_stop_log).to include('Deleting vm')
      end

      it 'passes BOSH_INSTANCE_NEXT_STATE when deleting the instance' do
        manifest_hash['instance_groups'].first['jobs'].first['properties']['fail_on_pre_stop'] = true
        deploy_from_scratch(
          cloud_config_hash: cloud_config_hash,
          manifest_hash: manifest_hash,
        )

        manifest_hash['instance_groups'].first['instances'] = 0
        deploy_from_scratch(
          cloud_config_hash: cloud_config_hash,
          manifest_hash: manifest_hash,
          failure_expected: true,
        )

        pre_stop_log = File.read(File.join(log_path, 'bazquux/pre-stop.stdout.log'))
        expect(pre_stop_log).to include('Deleting vm')
        expect(pre_stop_log).to include('Deleting instance')
      end

      it 'passes BOSH_DEPLOYMENT_NEXT_STATE when deleting the deployment' do
        manifest_hash['instance_groups'].first['jobs'].first['properties']['fail_on_pre_stop'] = true
        deploy_from_scratch(
          cloud_config_hash: cloud_config_hash,
          manifest_hash: manifest_hash,
        )

        bosh_runner.run('delete-deployment', deployment_name: 'simple', failure_expected: true)
        pre_stop_log = File.read(File.join(log_path, 'bazquux/pre-stop.stdout.log'))
        expect(pre_stop_log).to include('Deleting vm')
        expect(pre_stop_log).to include('Deleting instance')
        expect(pre_stop_log).to include('Deleting deployment')
      end
    end
  end

  describe 'when pre-stop script is broken' do
    let(:instance) { director.instance('bazquux', '0') }

    let(:manifest_hash_fails_on_prestop) do
      manifest_hash['instance_groups'].first['jobs'].first['properties']['fail_on_pre_stop'] = true
      manifest_hash
    end

    it 'stop execution if pre-stop script failed' do
      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash_fails_on_prestop)
      out = bosh_runner.run('stop bazquux/0', deployment_name: 'simple', failure_expected: true)
      expect(out).to include('pre-stop scripts failed')
    end
  end

  describe 'when --skip-drain is present' do
    it 'skips pre-stop if --skip-drain is present' do
      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
      out = bosh_runner.run('stop bazquux/0 --skip-drain', deployment_name: 'simple', failure_expected: true)
      task_number = out[/Task\s(\d+)\n/, 1]
      task_ouput = bosh_runner.run("task #{task_number} --debug")
      expect(task_ouput).to include("Skipping pre-stop and drain for '")
      drain_file = director.instance('bazquux', '0').file_path('pre-stop.stdout.log')
      expect(File).not_to exist(drain_file)
    end
  end
end
