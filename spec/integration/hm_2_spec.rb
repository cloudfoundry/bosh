require "spec_helper"

describe 'health_monitor: 2', type: :integration do
  context 'if fix_stateful_nodes director option is not set' do
    with_reset_sandbox_before_each(director_fix_stateful_nodes: false)
    before { current_sandbox.health_monitor_process.start }
    after { current_sandbox.health_monitor_process.stop }

    # ~6m
    it 'does not resurrect stateful nodes' do
      deployment_hash = Bosh::Spec::Deployments.simple_manifest
      deployment_hash['jobs'][0]['instances'] = 1
      deployment_hash['jobs'][0]['persistent_disk'] = 20_480
      deploy_from_scratch(manifest_hash: deployment_hash)

      # wait_for_vm will wait here maximum amount of time!
      director.vm('foobar/0').kill_agent
      expect(director.wait_for_vm('foobar/0', 150)).to be_nil
    end
  end

  # ~2m
  context 'if fix_stateful_nodes director option is set' do
    with_reset_sandbox_before_each(director_fix_stateful_nodes: true)
    before { current_sandbox.health_monitor_process.start }
    after { current_sandbox.health_monitor_process.stop }

    it 'resurrects stateful nodes ' do
      deployment_hash = Bosh::Spec::Deployments.simple_manifest
      deployment_hash['jobs'][0]['instances'] = 1
      deployment_hash['jobs'][0]['persistent_disk'] = 20_480
      deploy_from_scratch(manifest_hash: deployment_hash)

      original_vm = director.vm('foobar/0')
      original_vm.kill_agent
      resurrected_vm = director.wait_for_vm('foobar/0', 150)
      expect(resurrected_vm.cid).to_not eq(original_vm.cid)
    end
  end
end
