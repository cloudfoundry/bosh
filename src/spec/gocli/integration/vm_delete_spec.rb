require_relative '../spec_helper'

describe 'vm delete', type: :integration do
  include Bosh::Spec::BlockingDeployHelper
  with_reset_sandbox_before_each

  it 'delete the vm by its vm_cid' do
    deploy_from_scratch

    #reference to instance
    instance = director.instances.first
    expect(current_sandbox.cpi.has_vm(instance.vm_cid)).to be_truthy
    output = bosh_runner.run("delete-vm #{instance.vm_cid}", deployment_name: 'simple')
    expect(current_sandbox.cpi.has_vm(instance.vm_cid)).not_to be_truthy
    expect(output).to match /Delete VM: [0-9]{1,5}/
    expect(output).to match /Delete VM: VM [0-9]{1,5} is successfully deleted/
    expect(output).to match /Succeeded/

    #no reference to instance
    network ={'a' => {'ip' => '192.168.1.5', 'type' => 'dynamic'}}
    id = current_sandbox.cpi.create_vm(SecureRandom.uuid, current_sandbox.cpi.latest_stemcell['id'], {}, network, [], {})

    expect(current_sandbox.cpi.has_vm(id)).to be_truthy
    output = bosh_runner.run("delete-vm #{id}", deployment_name: 'simple')
    expect(current_sandbox.cpi.has_vm(id)).not_to be_truthy
    expect(output).to match /Delete VM: [0-9]{1,5}/
    expect(output).to match /Delete VM: VM [0-9]{1,5} is successfully deleted/
    expect(output).to match /Succeeded/

    #vm does not exists
    current_sandbox.cpi.commands.make_delete_vm_to_raise_vmnotfound
    output = bosh_runner.run("delete-vm #{id}", deployment_name: 'simple')

    expect(output).to match /Delete VM: [0-9]{1,5}/
    expect(output).to match /Warning: VM [0-9]{1,5} does not exist. Deletion is skipped/
    expect(output).to match /Succeeded/
  end
end
