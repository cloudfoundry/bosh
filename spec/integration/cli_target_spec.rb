require 'spec_helper'

describe 'cli: target', type: :integration do
  with_reset_sandbox_before_each

  before { bosh_runner.reset }

  it 'whines on inaccessible target', no_reset: true do
    out = bosh_runner.run('target https://localhost', failure_expected: true)
    expect(out).to match(/cannot access director/i)

    expect_output('target', <<-OUT)
      Target not set
    OUT
  end

  it 'sets correct target' do
    expect_output("target #{current_sandbox.director_url}", <<-OUT)
      Target set to `Test Director'
    OUT

    message = current_sandbox.director_url
    expect_output('target', message)
    Dir.chdir('/tmp') do
      expect_output('target', message)
    end
  end

  it 'uses correct certificate' do
    expect_output("target --ca-cert #{current_sandbox.certificate_path} #{current_sandbox.director_url}", <<-OUT)
      Target set to `Test Director'
    OUT
  end

  it 'does not let user use deployment with target anymore (needs uuid)', no_reset: true do
    out = bosh_runner.run('deployment vmforce', failure_expected: true)
    expect(out).to match(regexp('Please upgrade your deployment manifest'))
  end

  it 'remembers deployment when switching targets', no_reset: true do
    bosh_runner.run("target #{current_sandbox.director_url}")
    bosh_runner.run('deployment test2')

    expect_output("target https://0.0.0.0:#{current_sandbox.director_port}", <<-OUT)
      Target set to `Test Director'
    OUT

    expect_output('deployment', 'Deployment not set')
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
