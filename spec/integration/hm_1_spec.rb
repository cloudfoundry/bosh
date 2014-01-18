require "spec_helper"

describe Bosh::Spec::IntegrationTest::HealthMonitor do
  include IntegrationExampleGroup

  before { current_sandbox.health_monitor_process.start }
  after { current_sandbox.health_monitor_process.stop }

  before do
    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['instances'] = 1
    deploy_simple(manifest_hash: deployment_hash)
  end

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

  it 'resurrects stateless nodes' do
    original_cid = kill_job_agent('foobar/0')
    foobar_vm = wait_for_vm('foobar/0')
    expect(foobar_vm[:cid]).to_not eq original_cid
  end

  it 'does not resurrect stateless nodes when paused' do
    run_bosh('vm resurrection foobar 0 off')
    kill_job_agent('foobar/0')
    expect(wait_for_vm('foobar/0')).to be_nil
  end
end
