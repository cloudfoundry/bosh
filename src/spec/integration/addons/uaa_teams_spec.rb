require 'spec_helper'

describe 'teams', type: :integration do
  with_reset_sandbox_before_each(user_authentication: 'uaa')

  it 'allows addons to be added for the specified team' do
    dev_team_env = { 'BOSH_CLIENT' => 'dev_team', 'BOSH_CLIENT_SECRET' => 'secret' }
    production_team_env = { 'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret' }
    director_client_env = { client: 'director-access', client_secret: 'secret' }

    runtime_config = Bosh::Spec::DeploymentManifestHelper.runtime_config_with_addon
    runtime_config['addons'][0]['include'] = { 'teams' => ['production_team'] }
    runtime_config['addons'][0]['exclude'] = { 'teams' => ['dev_team'] }
    runtime_config_file = yaml_file('runtime_config.yml', runtime_config)

    expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}", director_client_env)).to include('Succeeded')

    bosh_runner.run("upload-release #{asset_path('bosh-release-0+dev.1.tgz')}", director_client_env)
    bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}", director_client_env)

    upload_stemcell(director_client_env)
    upload_cloud_config(director_client_env)

    manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups

    # deploy Deployment1
    manifest_hash['name'] = 'dep1'
    deploy_simple_manifest(manifest_hash: manifest_hash, env: production_team_env, include_credentials: false)

    foobar_instance = director.instance(
      'foobar', '0',
      deployment_name: 'dep1',
      client: production_team_env['BOSH_CLIENT'],
      client_secret: production_team_env['BOSH_CLIENT_SECRET']
    )

    expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
    template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
    expect(template).to include("echo 'addon_prop_value'")

    # deploy Deployment2
    manifest_hash['name'] = 'dep2'
    deploy_simple_manifest(manifest_hash: manifest_hash, env: dev_team_env, include_credentials: false)

    foobar_instance = director.instance(
      'foobar', '0',
      deployment_name: 'dep2',
      client: dev_team_env['BOSH_CLIENT'],
      client_secret: dev_team_env['BOSH_CLIENT_SECRET']
    )

    expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(false)

    expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)
  end
end
