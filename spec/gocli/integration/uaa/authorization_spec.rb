require_relative '../../spec_helper'

describe 'User authorization with UAA', type: :integration do
  # with_reset_sandbox_before_each(user_authentication: 'uaa')

  before do
    pending('cli2: #125440211: uaa path problem; we wanted to commit and push and pended for now')
    bosh_runner.run("env #{current_sandbox.director_url}", ca_cert: current_sandbox.certificate_path)
    bosh_runner.run('log-out')
  end

  it 'can view deployments made by a particular client' do
    client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
    prepare_for_deploy(include_credentials: false, no_login: true, env: client_env)

    client_env = {'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret'}
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_simple_manifest(include_credentials: false, no_login: true, env: client_env, manifest_hash: manifest_hash)

    output = bosh_runner.run('deployments', env: client_env, include_credentials: false)
    expect(output).to match /1 deployments/
    client_env = {'BOSH_CLIENT' => 'dev_team', 'BOSH_CLIENT_SECRET' => 'secret'}
    output = bosh_runner.run('deployments', env: client_env, failure_expected: true, include_credentials: false)
    expect(output).to match /0 deployments/

    client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
    output = bosh_runner.run('deployments', env: client_env, include_credentials: false)
    expect(output).to match /1 deployments/
  end

  it 'can deploy and delete a deployment as a team member' do
    client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
    prepare_for_deploy(no_login: true, include_credentials: false, env: client_env)

    client_env = {'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret'}
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_simple_manifest(no_login: true, env: client_env, include_credentials: false, manifest_hash: manifest_hash)

    output = bosh_runner.run('delete-deployment', deployment_name: 'simple', env: client_env, include_credentials: false)
    expect(output).to include("Using deployment 'simple'")
    expect(output).to include("Deleting instances")
    expect(output).to include("Deleting properties: Destroying deployment")
  end

  it 'should return tasks that user is permitted to view' do
    client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
    prepare_for_deploy(no_login: true, env: client_env, include_credentials: false)

    client_env = {'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret'}
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_simple_manifest(no_login: true, env: client_env, include_credentials: false, manifest_hash: manifest_hash)

    output = bosh_runner.run('delete-deployment', deployment_name: 'simple', env: client_env, include_credentials: false)
    expect(output).to include("Using deployment 'simple'")
    expect(output).to include("Deleting instances")
    expect(output).to include("Deleting properties: Destroying deployment")
    output = table(bosh_runner.run('tasks --recent', json: true, env: client_env, include_credentials: false))

    expect(output).to contain_exactly(
      {"#"=>"4",   "State"=>"done",  "Started At"=>/.*/,   "Last Activity At"=>/.*/,  "User"=>"production_team",  "Deployment"=>"simple",  "Description"=>"delete deployment simple",  "Result"=>"/deployments/simple"},
      {"#"=>"3",  "State"=>"done",  "Started At"=>/.*/,  "Last Activity At"=>/.*/,  "User"=>"production_team",  "Deployment"=>"simple",  "Description"=>"create deployment",  "Result"=>"/deployments/simple"}
    )
  end
end
