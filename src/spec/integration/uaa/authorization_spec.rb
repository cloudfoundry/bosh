require_relative '../../spec_helper'

describe 'User authorization with UAA', type: :integration do
  with_reset_sandbox_before_each(user_authentication: 'uaa')

  it 'can view deployments made by a particular client' do
    client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
    prepare_for_deploy(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config, environment_name: current_sandbox.director_url, include_credentials: false, no_login: true, env: client_env)

    client_env = {'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret'}
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['name'] = 'fake-name1'
    deploy_simple_manifest(environment_name: current_sandbox.director_url, include_credentials: false, no_login: true, env: client_env, manifest_hash: manifest_hash)

    output = bosh_runner.run('deployments', environment_name: current_sandbox.director_url, env: client_env , include_credentials: false)
    expect(output).to match /1 deployments/
    client_env = {'BOSH_CLIENT' => 'dev_team', 'BOSH_CLIENT_SECRET' => 'secret'}
    output = bosh_runner.run('deployments', environment_name: current_sandbox.director_url, env: client_env , failure_expected: true, include_credentials: false)
    expect(output).to match /0 deployments/

    client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
    output = bosh_runner.run('deployments', environment_name: current_sandbox.director_url, env: client_env , include_credentials: false)
    expect(output).to match /1 deployments/
  end

  it 'can deploy and delete a deployment as a team member' do
    client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
    prepare_for_deploy(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config, no_login: true, include_credentials: false, environment_name: current_sandbox.director_url, env: client_env )

    client_env = {'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret'}
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['name'] = 'fake-name1'
    deploy_simple_manifest(no_login: true, environment_name: current_sandbox.director_url, env: client_env , include_credentials: false, manifest_hash: manifest_hash)

    output = bosh_runner.run('delete-deployment', deployment_name: 'simple', environment_name: current_sandbox.director_url, env: client_env , include_credentials: false)
    expect(output).to include("Using deployment 'simple'")
    expect(output).to include('Deleting instances')
    expect(output).to include('Deleting properties: Destroying deployment')
  end

  it 'should return tasks that user is permitted to view' do
    client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
    prepare_for_deploy(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config, no_login: true, environment_name: current_sandbox.director_url, env: client_env , include_credentials: false)

    client_env = {'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret'}
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['name'] = 'fake-name1'
    deploy_simple_manifest(no_login: true, environment_name: current_sandbox.director_url, env: client_env , include_credentials: false, manifest_hash: manifest_hash)

    output = bosh_runner.run('delete-deployment', deployment_name: 'simple', environment_name: current_sandbox.director_url, env: client_env , include_credentials: false)
    expect(output).to include("Using deployment 'simple'")
    expect(output).to include('Deleting instances')
    expect(output).to include('Deleting properties: Destroying deployment')
    output = table(bosh_runner.run('tasks --recent', json: true, environment_name: current_sandbox.director_url, env: client_env , include_credentials: false))

    expect(output).to contain_exactly(
      {'id'=> '4',   'state'=> 'done',  'started_at'=>/.*/,   'last_activity_at'=>/.*/,  'user'=> 'production_team',  'deployment'=> 'simple',  'description'=> 'delete deployment simple',  'result'=> '/deployments/simple'},
      {'id'=> '3',  'state'=> 'done',  'started_at'=>/.*/,  'last_activity_at'=>/.*/,  'user'=> 'production_team',  'deployment'=> 'simple',  'description'=> 'create deployment',  'result'=> '/deployments/simple'}
    )
  end
end
