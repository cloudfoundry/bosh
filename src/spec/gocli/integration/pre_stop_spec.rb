require_relative '../spec_helper'

describe 'pre-stop', type: :integration do
  let(:deployment_name) { 'simple' }

  with_reset_sandbox_before_each

  describe 'when pre-stop script is present' do
    let(:instance) { director.instance('bazquux', '0') }
    let(:log_path) { "#{current_sandbox.agent_tmp_path}/agent-base-dir-#{instance.agent_id}/data/sys/log" }

    before do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['jobs'].first['name'] = 'bazquux'
      manifest_hash['releases'].first['version'] = 'latest'
      manifest_hash['instance_groups'].first['instances'] = 1
      manifest_hash['instance_groups'].first['name'] = 'bazquux'

      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    end

    it 'runs the pre-stop script on a job if pre-stop script is present' do
      bosh_runner.run('stop bazquux/0', deployment_name: 'simple')

      pre_stop_log = File.read(File.join(log_path, 'bazquux/pre-stop.stdout.log'))
      expect(pre_stop_log).to include('Running pre-stop')
    end
  end

  describe 'when pre-stop script is broken' do
    let(:instance) { director.instance('bazquux', '0') }

    before do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['jobs'].first['name'] = 'bazquux'
      manifest_hash['releases'].first['version'] = 'latest'
      manifest_hash['instance_groups'].first['instances'] = 1
      manifest_hash['instance_groups'].first['name'] = 'bazquux'

      manifest_hash['instance_groups'].first['jobs'].first['properties']['fail_on_pre_stop'] = true

      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    end

    it 'stop execution if pre-stop script failed' do
      out = bosh_runner.run('stop bazquux/0', deployment_name: 'simple', failure_expected: true)
      expect(out).to include('pre-stop scripts failed')
    end
  end
end
