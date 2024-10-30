require 'spec_helper'

describe 'cancel task', type: :integration do
  with_reset_sandbox_before_each

  it 'creates a task and then successfully cancels it' do
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
    cloud_config_hash['compilation']['workers'] = 1
    prepare_for_deploy(cloud_config_hash: cloud_config_hash)

    task_id = with_blocking_deploy do |task_id|
      bosh_runner.run("cancel-task #{task_id}")
    end

    output = bosh_runner.run("task #{task_id}", failure_expected: true)
    expect(output).to include("Task #{task_id} cancelled")
  end
end
