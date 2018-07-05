require_relative '../spec_helper'

describe 'deployment configs', type: :integration do
  with_reset_sandbox_before_each

  before do
    deploy_from_scratch(
      manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups,
      cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config,
    )
  end

  it 'should list deployment configs' do
    response = send_director_get_request('/deployment_configs', 'deployment[]=simple')
    deployment_configs = JSON.parse(response.read_body)
    expect(deployment_configs.first['id']).to be
    expect(deployment_configs.first['config']['name']).to eq('default')
  end
end
