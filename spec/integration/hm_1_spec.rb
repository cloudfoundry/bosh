require "spec_helper"

describe 'health_monitor: 1', type: :integration do
  with_reset_sandbox_before_each

  before { current_sandbox.health_monitor_process.start }
  after { current_sandbox.health_monitor_process.stop }

  before do
    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['instances'] = 1
    deploy_simple(manifest_hash: deployment_hash)
  end

  # ~50s
  it 'HM can be queried for stats' do
    varz = {}
    20.times do
      varz_json = RestClient.get("http://admin:admin@localhost:#{current_sandbox.hm_port}/varz")
      varz = Yajl::Parser.parse(varz_json)
      break if varz['deployments_count'] == 1
      sleep(0.5)
    end

    expect(varz['deployments_count']).to eq(1)
    expect(varz['agents_count']).to_not eq(0)
  end

  # ~1m20s
  it 'resurrects stateless nodes' do
    original_vm = director.vm('foobar/0')
    original_vm.kill_agent
    resurrected_vm = director.wait_for_vm('foobar/0', 300)
    expect(resurrected_vm.cid).to_not eq(original_vm.cid)
  end

  # ~8m
  it 'does not resurrect stateless nodes when paused' do
    run_bosh('vm resurrection foobar 0 off')
    original_vm = director.vm('foobar/0')
    original_vm.kill_agent
    expect(director.wait_for_vm('foobar/0', 300)).to be_nil
  end
end
