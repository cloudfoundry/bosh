require 'spec_helper'

describe 'vm resurrection', type: :integration do
  with_reset_sandbox_before_each

  it 'changes the resurrection state of vms by either index or vm uuid ' do
    skip("gobosh cannot turn off resurrection for specific vms - ask DK")
    deploy_from_scratch

    instances_before_state_switch = director.instances
    instance_before_with_index_0 = instances_before_state_switch.find{ |instance| instance.index == '0'}
    instance_before_with_index_1 = instances_before_state_switch.find{ |instance| instance.index == '1'}

    bosh_runner.run("vm resurrection #{instance_before_with_index_0.job_name} #{instance_before_with_index_0.index} disable")
    bosh_runner.run("vm resurrection #{instance_before_with_index_1.job_name} #{instance_before_with_index_1.id} disable")

    instances_after_state_switch = director.instances
    instance_after_with_index_0 = instances_after_state_switch.find{ |instance| instance.index == '0'}
    instance_after_with_index_1 = instances_after_state_switch.find{ |instance| instance.index == '1'}
    instance_after_with_index_2 = instances_after_state_switch.find{ |instance| instance.index == '2'}

    expect(instance_after_with_index_0.resurrection).to eq('paused')
    expect(instance_after_with_index_1.resurrection).to eq('paused')
    expect(instance_after_with_index_2.resurrection).to eq('active')
  end
end
