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
    task_yaml = yaml_file('task', Bosh::Spec::Deployments.simple_task_config(true))
    expect(bosh_runner.run("update-task-config #{task_yaml.path}")).to include("Succeeded")
    output = bosh_runner.run("task-config")
    expect(output).to include('paused: true')
    sleep 3

    current_target = current_sandbox.director_url
    pause_tasks = Thread.new do
      output = bosh_runner.run('delete-deployment', deployment_name: 'simple', environment_name: current_target)
      expect(output).to match(/Task \d+\ done/)
    end
    sleep 1

    output = bosh_runner.run('tasks --recent', deployment_name: 'simple')
    expect(output).to match(/\d+\s+queued .*  test  simple      delete deployment simple  -/)
    expect(output).to match(/\d+\s+done   .*  test  simple      create deployment         \/deployments\/simple/)

    task_yaml = yaml_file('task', Bosh::Spec::Deployments.simple_task_config(false))
    expect(bosh_runner.run("update-task-config #{task_yaml.path}")).to include("Succeeded")
    output = bosh_runner.run("task-config")
    expect(output).to include('paused: false')
    sleep 3

    pause_tasks.join
    output = bosh_runner.run('tasks --recent', deployment_name: 'simple')
    expect(output).to match(/\d+\s+done   .*  test  simple      delete deployment simple  \/deployments\/simple/)
    expect(output).to match(/\d+\s+done   .*  test  simple      create deployment         \/deployments\/simple/)
  end
end
