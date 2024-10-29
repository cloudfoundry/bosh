require 'spec_helper'

describe 'cancel tasks', type: :integration do
  with_reset_sandbox_before_each

  it 'cancels queued tasks' do
    director.insert_task('queued', 'update_deployment', 'cancel-deployment')
    director.insert_task('queued', 'update_deployment', 'cancel-deployment')

    bosh_runner.run('cancel-tasks')
    output = bosh_runner.run('tasks')
    expect(output.scan('cancelling').size).to eq(2)
  end

  it 'cancels all tasks of a deployment' do
    director.insert_task('queued', 'update_deployment', 'cancel-deployment')
    director.insert_task('queued', 'update_deployment', 'do-not-cancel')

    bosh_runner.run('cancel-tasks -d cancel-deployment')
    output = bosh_runner.run('tasks')
    expect(output.scan('cancelling').size).to eq(1)
  end

  it 'cancels tasks of a given type' do
    director.insert_task('queued', 'ssh', 'cancel-deployment')
    director.insert_task('queued', 'update_deployment', 'cancel-deployment')
    director.insert_task('queued', 'create_deployment', 'do-no-cancel')

    bosh_runner.run('cancel-tasks --type=ssh -t=update_deployment')
    output = bosh_runner.run('tasks')
    expect(output.scan('cancelling').size).to eq(2)
  end

  it 'cancels tasks of a given state' do
    director.insert_task('processing', 'ssh', 'cancel-deployment')
    director.insert_task('queued', 'update_deployment', 'cancel-deployment')
    director.insert_task('new', 'create_deployment', 'do-not-cancel-deployment')

    bosh_runner.run('cancel-tasks --state=processing -s=queued')
    output = bosh_runner.run('tasks')
    expect(output.scan('cancelling').size).to eq(2)
  end

  it 'cancels tasks of type ssh in state processing' do
    director.insert_task('queued', 'ssh', 'cancel-deployment')
    director.insert_task('processing', 'ssh', 'cancel-deployment')
    director.insert_task('processing', 'update_deployment', 'do-not-cancel-deployment')

    bosh_runner.run('cancel-tasks --state=processing --type=ssh')
    output = bosh_runner.run('tasks')
    expect(output.scan('cancelling').size).to eq(1)
  end
end
