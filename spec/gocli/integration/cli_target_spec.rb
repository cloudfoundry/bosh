require_relative '../spec_helper'

describe 'cli: environment', type: :integration do
  with_reset_sandbox_before_each(users_in_manifest: true)

  before { bosh_runner.reset }

  it 'whines on inaccessible target', no_reset: true do
    out = bosh_runner.run('environment https://localhost', failure_expected: true)
    expect(out).to match(/getsockopt: connection refused/i)
    expect { bosh_runner.run('environment') }
      .to raise_error(RuntimeError, /Expected non-empty Director URL/)
  end

  it 'sets correct target' do
    expect(bosh_runner.run("environment #{current_sandbox.director_url}")).to match_output "Name      #{current_sandbox.director_name}"

    expect(bosh_runner.run('environment', environment_name: current_sandbox.director_url)).to match_output "Current environment is '#{current_sandbox.director_url}'"
    Dir.chdir('/tmp') do
      expect(bosh_runner.run('environment', environment_name: current_sandbox.director_url)).to match_output "Current environment is '#{current_sandbox.director_url}'"
    end
  end

  it 'keeps track of user associated with target' do
    bosh_runner.run("environment #{current_sandbox.director_url} foo")
    bosh_runner.run('log-in --user=test --password=test', environment_name: "foo")

    bosh_runner.run("environment https://0.0.0.0:#{current_sandbox.director_port} bar")
    bosh_runner.run('log-in --user=hm --password=pass', environment_name: "bar")

    expect(bosh_runner.run('environment', environment_name: "bar")).to match(/user\s+hm/i)
    expect(bosh_runner.run('environment', environment_name: "foo")).to match(/user\s+test/i)
  end
end
