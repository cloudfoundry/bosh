require 'spec_helper'

describe 'a very simple deploy', type: :integration do
  with_reset_sandbox_before_each

  before do
    deploy_from_scratch(
      manifest_hash: SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups,
      cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config,
    )
  end

  it 'should contain the worker name in the debug log' do
    output = bosh_runner.run('task --debug 3')

    # sanity test with static expectation
    expect(output).to match(/Starting task: 3$/)

    # we currently run three workers
    expect(output).to match(%r{Running from worker 'worker_(0|1|2)' on some-name\/some-id \(127\.1\.127\.1\)$})
  end
end
