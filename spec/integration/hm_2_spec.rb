require "spec_helper"

describe 'health_monitor: 2', type: :integration do
  with_reset_sandbox_before_each

  before { current_sandbox.health_monitor_process.start }
  after { current_sandbox.health_monitor_process.stop }

  # ~6m
  it 'does not resurrect stateful nodes by default' do
    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['instances'] = 1
    deployment_hash['jobs'][0]['persistent_disk'] = 20_480
    deploy_simple(manifest_hash: deployment_hash)

    director.vm('foobar/0').kill_agent
    expect(director.wait_for_vm('foobar/0', 300)).to be_nil
  end

  # ~2m
  it 'resurrects stateful nodes if fix_stateful_nodes director option is set' do
    current_sandbox.director_fix_stateful_nodes = true
    current_sandbox.reconfigure_director

    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['instances'] = 1
    deployment_hash['jobs'][0]['persistent_disk'] = 20_480
    deploy_simple(manifest_hash: deployment_hash)

    original_vm = director.vm('foobar/0')
    original_vm.kill_agent
    resurrected_vm = director.wait_for_vm('foobar/0', 300)
    expect(resurrected_vm.cid).to_not eq(original_vm.cid)
  end

  context 'when there are open problems before resurrector starts' do
    # ~3m
    it 'resolves the problems' do
      # Turn resurrector off
      current_sandbox.reconfigure_health_monitor('health_monitor_without_resurrector.yml.erb')

      deployment_hash = Bosh::Spec::Deployments.simple_manifest
      deployment_hash['jobs'][0]['instances'] = 2
      deploy_simple(manifest_hash: deployment_hash)

      director.vm('foobar/0').kill_agent
      director.vm('foobar/1').kill_agent

      _, exit_code = run_bosh('cck --report', failure_expected: true, return_exit_code: true)
      expect(exit_code).to eq(1)

      # Turn resurrector back on
      current_sandbox.reconfigure_health_monitor('health_monitor.yml.erb')

      expect(director.wait_for_vm('foobar/0', 300)).to_not be_nil
      expect(director.wait_for_vm('foobar/1', 300)).to_not be_nil
    end
  end
end
