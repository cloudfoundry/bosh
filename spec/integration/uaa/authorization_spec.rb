require 'spec_helper'

describe 'User authorization with UAA', type: :integration do
  with_reset_sandbox_before_each(user_authentication: 'uaa')

  before do
    bosh_runner.run("target #{current_sandbox.director_url}", ca_cert: current_sandbox.certificate_path)
    bosh_runner.run('logout')
  end

  it 'can view deployments made by a particular client' do
    client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
    prepare_for_deploy(no_login: true, env: client_env)

    client_env = {'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret'}
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_simple_manifest(no_login: true, env: client_env, manifest_hash: manifest_hash)

    output = bosh_runner.run('deployments', env: client_env)
    expect(output).to match /Deployments total: 1/

    client_env = {'BOSH_CLIENT' => 'dev_team', 'BOSH_CLIENT_SECRET' => 'secret'}
    output = bosh_runner.run('deployments', env: client_env, failure_expected: true)
    expect(output).to match /No deployments/

    client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
    output = bosh_runner.run('deployments', env: client_env)
    expect(output).to match /Deployments total: 1/
  end

  it 'can deploy and delete a deployment as a team member' do
    client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
    prepare_for_deploy(no_login: true, env: client_env)

    client_env = {'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret'}
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_simple_manifest(no_login: true, env: client_env, manifest_hash: manifest_hash)

    output = bosh_runner.run('delete deployment simple', env: client_env)
    expect(output).to include("Deleted deployment 'simple'")
  end

  it 'should return tasks that user is permitted to view' do
    client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
    prepare_for_deploy(no_login: true, env: client_env)

    client_env = {'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret'}
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_simple_manifest(no_login: true, env: client_env, manifest_hash: manifest_hash)

    output = bosh_runner.run('delete deployment simple', env: client_env)
    expect(output).to include("Deleted deployment 'simple'")
    output = bosh_runner.run('tasks recent', env: client_env)

    expect(output).to match /| 4 | done  | .* | test | simple     | delete deployment simple | \/deployments\/simple |/
    expect(output).to match /| 3 | done  | .* | test | simple     | create deployment        | \/deployments\/simple |/
    expect(output).not_to match /create stemcell/
    expect(output).not_to match /create release/
  end
end
