require 'spec_helper'

describe 'vm delete', type: :integration do
  include Bosh::Spec::BlockingDeployHelper
  with_reset_sandbox_before_each

  it 'delete the vm by its vm_cid' do
    deploy_from_scratch

    #reference to instance
    instance = director.instances.first
    expect(current_sandbox.cpi.has_vm?(instance.vm_cid)).to be_truthy
    bosh_runner.run("delete vm #{instance.vm_cid}")
    expect(current_sandbox.cpi.has_vm?(instance.vm_cid)).not_to be_truthy

    #no reference to instance
    network ={'a' => {'ip' => '192.168.1.5', 'type' => 'dynamic'}}
    id = current_sandbox.cpi.create_vm(SecureRandom.uuid, current_sandbox.cpi.latest_stemcell['id'], {}, network, [], {})

    expect(current_sandbox.cpi.has_vm?(id)).to be_truthy
    bosh_runner.run("delete vm #{id}")
    expect(current_sandbox.cpi.has_vm?(id)).not_to be_truthy

    #vm does not exists
    expect { bosh_runner.run("delete vm #{id}") }.not_to raise_error
  end
end
