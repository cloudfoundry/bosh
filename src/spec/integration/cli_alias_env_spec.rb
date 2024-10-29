require 'spec_helper'

describe 'cli: alias-env', type: :integration do
  with_reset_sandbox_before_each(users_in_manifest: true)

  before { bosh_runner.reset }

  it 'creates an alias' do
    bosh_runner.run('alias-env my-alias')
    output = bosh_runner.run('env', environment_name: 'my-alias')
    expect(output).to include('Succeeded')
    expect(output).to include(current_sandbox.director_url)
  end

  it 'whines on inaccessible environment', no_reset: true do
    bosh_runner.run('alias-env my-alias', environment_name: 'https://example.com', failure_expected: true)
  end

  it 'keeps track of user associated with target' do
    bosh_runner.run('alias-env foo', environment_name: current_sandbox.director_url)
    bosh_runner.run('log-in', environment_name: 'foo', client: 'test', client_secret: 'test')

    bosh_runner.run('alias-env bar', environment_name: "https://0.0.0.0:#{current_sandbox.director_port}")
    bosh_runner.run('log-in', environment_name: 'bar', client: 'hm', client_secret: 'pass')

    expect(bosh_runner.run('environment', environment_name: 'bar', include_credentials: false)).to match(/user\s+hm/i)
    expect(bosh_runner.run('environment', environment_name: 'foo', include_credentials: false)).to match(/user\s+test/i)
  end
end
