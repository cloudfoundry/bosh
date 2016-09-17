require_relative '../spec_helper'

describe 'cli: env', type: :integration do
  with_reset_sandbox_before_each

  before { bosh_runner.reset }

  it 'whines on inaccessible env', no_reset: true do
    out = bosh_runner.run('env https://localhost', failure_expected: true)
    expect(out).to match(/GET 'https:\/\/localhost/)
    expect(out).to match(/Exit code 1/)
    expect { bosh_runner.run('env') }
      .to raise_error(RuntimeError, /Expected non-empty Director URL/)
  end

  it 'sets correct env' do
    expect(bosh_runner.run("env #{current_sandbox.director_url}")).to match_output "Environment set to '#{current_sandbox.director_url}'"

    message = current_sandbox.director_url
    expect(bosh_runner.run('env')).to match_output message
    Dir.chdir('/tmp') do
      expect(bosh_runner.run('env')).to match_output message
    end
  end

  it 'remembers deployment when switching envs', no_reset: true do
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

  it 'stays logged in for each env' do
    bosh_runner.run("env #{current_sandbox.director_url} foo")
    # not logged in yet
    out = bosh_runner.run('deployments', include_credentials: false, failure_expected: true)
    expect(out).to match(/Not authorized/)

    bosh_runner.run('log-in', user: 'test', password: 'test')
    out = bosh_runner.run('deployments', include_credentials: false)
    expect(out).to match(/Succeeded/)

    bosh_runner.run("env https://0.0.0.0:#{current_sandbox.director_port} bar")
    # on new env, not logged in yet
    out = bosh_runner.run('deployments', include_credentials: false, failure_expected: true)
    expect(out).to match(/Not authorized/)

    bosh_runner.run('log-in', user: 'test', password: 'test')
    out = bosh_runner.run('deployments', include_credentials: false)
    expect(out).to match(/Succeeded/)

    # back to first env, should still be logged in
    bosh_runner.run('env foo')
    out = bosh_runner.run('deployments', include_credentials: false)
    expect(out).to match(/Succeeded/)
  end
end
