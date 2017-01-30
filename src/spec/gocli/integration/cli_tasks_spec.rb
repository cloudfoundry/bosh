require_relative '../spec_helper'

describe 'cli: tasks', type: :integration do
  with_reset_sandbox_before_each

  it 'should return task list' do
    deploy_from_scratch
    bosh_runner.run('delete-deployment', deployment_name: 'simple')
    output = bosh_runner.run('tasks --recent', deployment_name: 'simple')

    expect(output).to match /4   done   .*  test  simple      delete deployment simple  \/deployments\/simple/
    expect(output).to match /3   done   .*  test  simple      create deployment         \/deployments\/simple/
    expect(output).not_to match /create stemcell/
    expect(output).not_to match /create release/
  end

  it 'should pause/unpause tasks' do
    deploy_from_scratch
    out = bosh_runner.run('pause-tasks')
    expect(out).to include("Succeeded")
    out = bosh_runner.run('env')
    expect(out).to include("pause_tasks: enabled")

    sleep 3

    output = bosh_runner.run('delete-deployment', deployment_name: 'simple')
    expect(output).to match(/Task \d+\. Paused/)

    output = bosh_runner.run('tasks --recent', deployment_name: 'simple')
    expect(output).to match(/\d+  queued .*  test  simple      delete deployment simple  -/)
    expect(output).to match(/\d+  done   .*  test  simple      create deployment         \/deployments\/simple/)

    out = bosh_runner.run('unpause-tasks')
    expect(out).to include("Succeeded")
    out = bosh_runner.run('env')
    expect(out).to include("pause_tasks: disabled")
    sleep 3

    output = bosh_runner.run('tasks --recent', deployment_name: 'simple')
    expect(output).to match(/\d+  done   .*  test  simple      delete deployment simple  \/deployments\/simple/)
    expect(output).to match(/\d+  done   .*  test  simple      create deployment         \/deployments\/simple/)
  end
end
