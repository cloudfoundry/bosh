require 'spec_helper'

describe 'cli: target', type: :integration do
  with_reset_sandbox_before_each

  before { bosh_runner.reset }

  it 'whines on inaccessible target', no_reset: true do
    out = bosh_runner.run('target https://localhost', failure_expected: true)
    expect(out).to match(/cannot access director/i)
    expect { bosh_runner.run('target') }
      .to raise_error(RuntimeError, /Target not set/)
  end

  it 'sets correct target' do
    expect(bosh_runner.run("target #{current_sandbox.director_url}")).to match_output "Target set to '#{current_sandbox.director_name}'"

    message = current_sandbox.director_url
    expect(bosh_runner.run('target')).to match_output message
    Dir.chdir('/tmp') do
      expect(bosh_runner.run('target')).to match_output message
    end
  end

  it 'does not let user use deployment with target anymore (needs uuid)', no_reset: true do
    out = bosh_runner.run('deployment vmforce', failure_expected: true)
    expect(out).to match(regexp('Please upgrade your deployment manifest'))
  end

  it 'remembers deployment when switching targets', no_reset: true do
    bosh_runner.run("target #{current_sandbox.director_url}")
    bosh_runner.run('deployment test2')

    expect(bosh_runner.run("target https://0.0.0.0:#{current_sandbox.director_port}"))
      .to match_output "Target set to '#{current_sandbox.director_name}'"

    expect { bosh_runner.run('deployment') }
      .to raise_error(RuntimeError, /Deployment not set/)
    bosh_runner.run("target #{current_sandbox.director_url}")
    out = bosh_runner.run('deployment')
    expect(out).to match(regexp('test2'))
  end

  it 'keeps track of user associated with target' do
    bosh_runner.run("target #{current_sandbox.director_url} foo")
    bosh_runner.run('login test test')

    bosh_runner.run("target https://0.0.0.0:#{current_sandbox.director_port} bar")

    bosh_runner.run('login test test')
    expect(bosh_runner.run('status')).to match(/user\s+test/i)

    bosh_runner.run('target foo')
    expect(bosh_runner.run('status')).to match(/user\s+test/i)
  end
end
