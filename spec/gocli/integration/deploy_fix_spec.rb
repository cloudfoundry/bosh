require_relative '../spec_helper'

describe 'deploy_fix', type: :integration do
  with_reset_sandbox_before_each

  it 'fix unresponsive vms' do
    pending("cli2: #131667933: backport --fix flag for recreate")
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'][0]['persistent_disk'] = 1
    deploy_from_scratch({manifest_hash: manifest_hash})
    current_sandbox.cpi.kill_agents

    manifest_hash['jobs'][0]['instances'] = 2
    manifest_hash['jobs'][0]['persistent_disk'] = 10
    deploy(manifest_hash: manifest_hash, fix: true)

    vms = director.vms
    expect(vms.size).to eq(2)
    expect(vms.map(&:last_known_state).uniq).to match_array(['running'])

    vm_to_recreate = director.find_vm(vms, 'foobar', '0')
    vm_to_recreate.kill_agent
    expect(bosh_runner.run('recreate foobar/0 --fix', deployment_name: 'simple')).to match /Updating instance foobar: foobar\/0 /
    vm_was_recreated = director.find_vm(director.vms, 'foobar', '0')
    expect(vm_was_recreated.cid).to_not eq(vm_to_recreate.cid)
  end
end
