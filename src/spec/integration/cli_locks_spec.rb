require 'spec_helper'

describe 'cli: locks', type: :integration do
  with_reset_sandbox_before_each

  context 'when a deployment is in progress' do
    it 'lists a deployment lock' do
      prepare_for_deploy(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)

      with_blocking_deploy do
        locks_json = JSON.parse(bosh_runner.run_until_succeeds('locks --json', number_of_retries: 30))
        expect(locks_json['Tables'][0]['Rows']).to include({'type' => 'deployment', 'resource' => 'blocking', 'expires_at' => anything, 'task_id' => /^[\d]*$/})
      end
    end
  end
end
