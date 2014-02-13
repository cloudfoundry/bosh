require "spec_helper"

describe 'Bosh::Spec::IntegrationTest::HealthMonitor 2' do
  include IntegrationExampleGroup

  before { current_sandbox.health_monitor_process.start }
  after { current_sandbox.health_monitor_process.stop }

  it 'does not resurrect stateful nodes by default' do
    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['name'] = 'foobar_ng'
    deployment_hash['jobs'][0]['instances'] = 1
    deployment_hash['jobs'][0]['persistent_disk'] = 20_480
    deploy_simple(manifest_hash: deployment_hash)

    kill_job_agent('foobar_ng/0')
    expect(wait_for_vm('foobar_ng/0')).to be_nil
  end

  it 'resurrects stateful nodes if fix_stateful_nodes director option is set' do
    current_sandbox.director_fix_stateful_nodes = true
    current_sandbox.reconfigure_director

    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['name'] = 'foobar_ng'
    deployment_hash['jobs'][0]['instances'] = 1
    deployment_hash['jobs'][0]['persistent_disk'] = 20_480
    deploy_simple(manifest_hash: deployment_hash)

    original_cid = kill_job_agent('foobar_ng/0')
    foobar_ng_vm = wait_for_vm('foobar_ng/0')
    expect(foobar_ng_vm[:cid]).to_not eq(original_cid)
  end

  context 'when there are open problems before resurrector starts' do
    it 'resolves the problems' do
      # turn resurrector off
      current_sandbox.reconfigure_health_monitor('health_monitor_without_resurrector.yml.erb')

      deployment_hash = Bosh::Spec::Deployments.simple_manifest
      deployment_hash['jobs'][0]['name'] = 'foobar_ng'
      deployment_hash['jobs'][0]['instances'] = 2
      deploy_simple(manifest_hash: deployment_hash)

      kill_job_agent('foobar_ng/0')
      kill_job_agent('foobar_ng/1')

      run_bosh('cck --report', failure_expected: true)

      # turn resurrector back on
      current_sandbox.reconfigure_health_monitor('health_monitor.yml.erb')

      wait_for_vm('foobar_ng/0')
      wait_for_vm('foobar_ng/1')
    end
  end

end
