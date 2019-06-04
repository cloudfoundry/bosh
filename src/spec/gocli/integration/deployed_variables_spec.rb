require_relative '../spec_helper'

describe 'deployed variables endpoint', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa') # <- user

  let(:deployment_name) { manifest_hash['name'] }
  let(:director_name) { current_sandbox.director_name }
  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger) }
  let(:manifest_hash) do
    Bosh::Spec::NewDeployments.manifest_with_release.merge(
      'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
        name: 'foobar',
        jobs: [
          { 'name' => 'job_with_property_types',
            'release' => 'bosh-release',
            'properties' => job_properties },
        ],
        instances: 1,
      )],
    )
  end
  let(:cloud_config) { Bosh::Spec::NewDeployments.simple_cloud_config }
  let(:client_env) do
    { 'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => current_sandbox.certificate_path.to_s }
  end
  let(:job_properties) do
    {
      'gargamel' => {
        'secret_recipe' => 'poutine',
      },
      'smurfs' => {
        'happiness_level' => '((happiness_level))',
        'phone_password' => '12345',
      },
    }
  end

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  it 'can list deployed_variables' do
    config_server_helper.put_value(prepend_namespace('happiness_level'), 'sad')
    config_server_helper.put_value(prepend_namespace('happiness_level'), 'elated')

    deploy_from_scratch(
      manifest_hash: manifest_hash,
      cloud_config_hash: cloud_config,
      include_credentials: false,
      env: client_env,
    )

    output = bosh_runner.run(
      "curl /deployed_variables/#{CGI.escape(prepend_namespace('happiness_level'))}",
      include_credentials: false,
      env: client_env,
      json: true,
    )
    parsed_output = JSON.parse(JSON.parse(output)['Blocks'][0])

    expect(parsed_output['deployments'][0]['name']).to eq(deployment_name)
    expect(parsed_output['deployments'][0]['version']).to eq('1')
  end
end
