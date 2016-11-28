require_relative '../spec_helper'

describe 'deploy_fix', type: :integration do
  with_reset_sandbox_before_each

  it 'fix unresponsive vms' do
    doTest
  end

  context 'when sending templates over nats' do
    with_reset_sandbox_before_each(enable_nats_delivered_templates: true)
    it 'fix unresponsive vms' do
      doTest
    end
  end

  def doTest
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'][0]['persistent_disk'] = 1
    deploy_from_scratch({manifest_hash: manifest_hash})
    current_sandbox.cpi.kill_agents

    manifest_hash['jobs'][0]['instances'] = 2
    manifest_hash['jobs'][0]['persistent_disk'] = 10
    deploy(manifest_hash: manifest_hash, fix: true)

    instances = director.instances
    expect(instances.size).to eq(2)
    expect(instances.map(&:last_known_state).uniq).to match_array(['running'])

    instance_to_recreate = director.find_instance(instances, 'foobar', '0')
    instance_to_recreate.kill_agent
    expect(bosh_runner.run('recreate foobar/0 --fix', deployment_name: 'simple')).to match /Updating instance foobar: foobar\/[a-z0-9-]+ \(0\) /
    instance_was_recreated = director.find_instance(director.instances, 'foobar', '0')
    expect(instance_was_recreated.vm_cid).to_not eq(instance_to_recreate.vm_cid)
  end
end
