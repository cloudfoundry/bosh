require_relative '../spec_helper'

describe 'events endpoint access', type: :integration do
  with_reset_sandbox_before_each(user_authentication: 'uaa')

  director_client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
  team_client_read_env = {'BOSH_CLIENT' => 'team-client-read-access', 'BOSH_CLIENT_SECRET' => 'team-secret'}
  team_client_admin_env = {'BOSH_CLIENT' => 'team-client', 'BOSH_CLIENT_SECRET' => 'team-secret'}
  no_access_client_env = {'BOSH_CLIENT' => 'no-access', 'BOSH_CLIENT_SECRET' => 'secret'}

  before do

    deployment_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    deployment_hash['instance_groups'][0]['instances'] = 1

    deploy_from_scratch(manifest_hash: deployment_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config, client: director_client_env['BOSH_CLIENT'], client_secret: director_client_env['BOSH_CLIENT_SECRET'])
  end

  def run_events_cmd(env)
    return bosh_runner.run('events',
      client: env['BOSH_CLIENT'],
      client_secret: env['BOSH_CLIENT_SECRET'],
      return_exit_code: true,
      failure_expected: true
    )
  end

  it 'bosh.teams.X.read should be able to see all events in the director' do
    output, exit_code = run_events_cmd(team_client_read_env)

    expect(exit_code).to eq(0)
    expect(output).to include '37 events'
  end

  it 'bosh.teams.X.admin should be able to see all events in the director' do
    output, exit_code = run_events_cmd(team_client_admin_env)

    expect(exit_code).to eq(0)
    expect(output).to include '37 events'
  end

  it 'bosh.X.admin should be able to see all events in the director' do
    output, exit_code = run_events_cmd(director_client_env)

    expect(exit_code).to eq(0)
    expect(output).to include '37 events'
  end

  it 'no-access should not be able to see all events in the director' do
    output, exit_code = run_events_cmd(no_access_client_env)

    expect(exit_code).to_not eq(0)
    expect(output).to_not include '37 events'
  end
end
