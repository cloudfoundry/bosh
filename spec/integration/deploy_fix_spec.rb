require 'spec_helper'

describe 'deploy_fix', type: :integration do
  with_reset_sandbox_before_each

  it 'fix unresponsive vms' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'][0]['persistent_disk'] = 1
    deploy_from_scratch({manifest_hash: manifest_hash})
    current_sandbox.cpi.commands.make_delete_vm_to_raise_vmnotfound
    current_sandbox.cpi.kill_agents

    manifest_hash['jobs'][0]['instances'] = 2
    manifest_hash['jobs'][0]['persistent_disk'] = 10
    set_deployment(manifest_hash: manifest_hash)
    deploy({fix: true})

    vms = director.vms
    expect(vms.size).to eq(2)
    expect(vms.map(&:last_known_state).uniq).to match_array(['running'])

    vm0_to_recreate = director.find_vm(vms, 'foobar', '0')
    vm1_to_recreate = director.find_vm(vms, 'foobar', '1')
    vm0_to_recreate.kill_agent
    current_sandbox.cpi.delete_vm(vm1_to_recreate.cid)
    expect(bosh_runner.run('recreate foobar --fix')).to match(/foobar\/\* recreated/)
    vms = director.vms
    vm0_was_recreated = director.find_vm(vms, 'foobar', '0')
    vm1_was_recreated = director.find_vm(vms, 'foobar', '1')
    expect(vm0_was_recreated.cid).to_not eq(vm0_to_recreate.cid)
    expect(vm1_was_recreated.cid).to_not eq(vm1_to_recreate.cid)
  end
end
