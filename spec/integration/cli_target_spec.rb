require 'spec_helper'

describe 'cli: target', type: :integration do
  with_reset_sandbox_before_each

  it 'whines on inaccessible target', no_reset: true do
    out = bosh_runner.run('target http://localhost', failure_expected: true)
    expect(out).to match(/cannot access director/i)

    expect_output('target', <<-OUT)
      Target not set
    OUT
  end

  it 'sets correct target' do
    expect_output("target http://localhost:#{current_sandbox.director_port}", <<-OUT)
      Target set to `Test Director'
    OUT

    message = "http://localhost:#{current_sandbox.director_port}"
    expect_output('target', message)
    Dir.chdir('/tmp') do
      expect_output('target', message)
    end
  end

  it 'does not let user use deployment with target anymore (needs uuid)', no_reset: true do
    out = bosh_runner.run('deployment vmforce', failure_expected: true)
    expect(out).to match(regexp('Please upgrade your deployment manifest'))
  end

  it 'remembers deployment when switching targets', no_reset: true do
    bosh_runner.run("target http://localhost:#{current_sandbox.director_port}")
    bosh_runner.run('deployment test2')

    expect_output("target http://localhost:#{current_sandbox.director_port}", <<-OUT)
      Target already set to `Test Director'
    OUT

    expect_output("target http://127.0.0.1:#{current_sandbox.director_port}", <<-OUT)
      Target set to `Test Director'
    OUT

    expect_output('deployment', 'Deployment not set')
    bosh_runner.run("target http://localhost:#{current_sandbox.director_port}")
    out = bosh_runner.run('deployment')
    expect(out).to match(regexp('test2'))
  end

  it 'keeps track of user associated with target' do
    bosh_runner.run("target http://localhost:#{current_sandbox.director_port} foo")
    bosh_runner.run('login admin admin')

    bosh_runner.run("target http://127.0.0.1:#{current_sandbox.director_port} bar")

    bosh_runner.run('login admin admin')
    expect(bosh_runner.run('status')).to match(/user\s+admin/i)

    bosh_runner.run('target foo')
    expect(bosh_runner.run('status')).to match(/user\s+admin/i)
  end
end
