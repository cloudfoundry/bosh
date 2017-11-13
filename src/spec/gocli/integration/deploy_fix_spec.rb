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
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'][0]['persistent_disk'] = 1
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
    current_sandbox.cpi.commands.make_delete_vm_to_raise_vmnotfound
    current_sandbox.cpi.kill_agents

    manifest_hash['instance_groups'][0]['instances'] = 2
    manifest_hash['instance_groups'][0]['persistent_disk'] = 10
    deploy(manifest_hash: manifest_hash, fix: true)

    instances = director.instances
    expect(instances.size).to eq(2)
    expect(instances.map(&:last_known_state).uniq).to match_array(['running'])

    instance0_to_recreate = director.find_instance(instances, 'foobar', '0')
    instance1_to_recreate = director.find_instance(instances, 'foobar', '1')
    instance0_to_recreate.kill_agent
    current_sandbox.cpi.delete_vm(instance1_to_recreate.vm_cid)
    output = bosh_runner.run('recreate foobar --fix', deployment_name: 'simple')
    expect(output).to match(/Updating instance foobar: foobar\/[a-z0-9-]+ \(0\) /)
    expect(output).to match(/Updating instance foobar: foobar\/[a-z0-9-]+ \(1\) /)
    expect(output).to match(/Succeeded/)
    instance0_was_recreated = director.find_instance(director.instances, 'foobar', '0')
    instance1_was_recreated = director.find_instance(director.instances, 'foobar', '1')
    expect(instance0_was_recreated.vm_cid).to_not eq(instance0_to_recreate.vm_cid)
    expect(instance1_was_recreated.vm_cid).to_not eq(instance1_to_recreate.vm_cid)
  end
end
