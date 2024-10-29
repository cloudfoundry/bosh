require 'spec_helper'

describe 'when compilation vm fails to respond', type: :integration do
  with_reset_sandbox_before_each(agent_wait_timeout: 1)

  before do
    create_and_upload_test_release
    upload_stemcell
  end

  it 'deletes compilation VM only once' do
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    upload_cloud_config(cloud_config_hash: cloud_config)

    Thread.current[:sandbox].stop_nats

    deploy_simple_manifest(
      manifest_hash: Bosh::Spec::Deployments.simple_manifest_with_instance_groups(instances: 1),
      failure_expected: true,
    )

    task_debug_logs = bosh_runner.run('task --debug 3', failure_expected: true)
    expect(task_debug_logs).to_not include('Attempt to delete object did not result in a single'\
                                           ' row modification')
    expect(task_debug_logs).to include('Timed out pinging')
  end
end
