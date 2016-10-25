require_relative '../spec_helper'

describe 'cli: environment', type: :integration do
  with_reset_sandbox_before_each

  before { bosh_runner.reset }

  it 'whines on inaccessible target', no_reset: true do
    out = bosh_runner.run('environment https://localhost', failure_expected: true)
    expect(out).to match(/getsockopt: connection refused/i)
    expect { bosh_runner.run('environment') }
      .to raise_error(RuntimeError, /Expected non-empty Director URL/)
  end

  it 'sets correct target' do
    expect(bosh_runner.run("environment #{current_sandbox.director_url}")).to match_output "Name      #{current_sandbox.director_name}"

    expect(bosh_runner.run('environment')).to match_output "Current environment is '#{current_sandbox.director_url}'"
    Dir.chdir('/tmp') do
      expect(bosh_runner.run('environment')).to match_output "Current environment is '#{current_sandbox.director_url}'"
    end
  end

  it 'remembers deployment when switching targets', no_reset: true do
    bosh_runner.run("env #{current_sandbox.director_url}")
    bosh_runner.run('deployment test2')

    expect(bosh_runner.run("env https://0.0.0.0:#{current_sandbox.director_port}"))
      .to match_output "Environment set to 'https://0.0.0.0:#{current_sandbox.director_port}'"

    expect { bosh_runner.run('deployment') }
      .to raise_error(RuntimeError, /Expected non-empty deployment name/)
    bosh_runner.run("env #{current_sandbox.director_url}")
    out = bosh_runner.run('deployment')
    expect(out).to match(regexp('test2'))
  end

  it 'keeps track of user associated with target' do
    bosh_runner.run("environment #{current_sandbox.director_url} foo")
    bosh_runner.run('log-in --user=test --password=test')

    bosh_runner.run("environment https://0.0.0.0:#{current_sandbox.director_port} bar")
    bosh_runner.run('log-in --user=test --password=test')

    expect(bosh_runner.run('environment')).to match(/user\s+test/i)

    bosh_runner.run('environment foo')
    expect(bosh_runner.run('environment')).to match(/user\s+test/i)
  end
end
