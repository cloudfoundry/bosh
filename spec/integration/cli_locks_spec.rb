require 'spec_helper'

describe 'cli: locks', type: :integration do
  with_reset_sandbox_before_each

  context 'when a deployment is in progress' do
    let(:blocking_deployment_manifest) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['jobs'][0]['template'] = 'job_with_blocking_compilation'
      manifest_hash['jobs'][0]['instances'] = 1
      manifest_hash
    end

    it 'lists a deployment lock' do
      deploy_result = deploy_from_scratch(manifest_hash: blocking_deployment_manifest, no_track: true)
      task_id = Bosh::Spec::OutputParser.new(deploy_result).task_id('running')
      director.wait_for_first_available_vm

      output = bosh_runner.run_until_succeeds('locks', number_of_retries: 30)
      expect(output).to match(/\s*\|\s*deployment\s*\|\s*simple\s*\|/)

      director.vms.first.unblock_package
      bosh_runner.run("task #{task_id}") # wait for task to complete
    end
  end

  context 'when nothing is in progress' do
    it 'returns no locks' do
      target_and_login
      expect_output('locks', 'No locks')
    end
  end
end
