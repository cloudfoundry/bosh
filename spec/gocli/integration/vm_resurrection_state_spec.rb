require 'spec_helper'

describe 'vm resurrection', type: :integration do
  with_reset_sandbox_before_each

  it 'changes the resurrection state of vms by either index or vm uuid ' do
    skip("gobosh cannot turn off resurrection for specific vms - ask DK")
    deploy_from_scratch

    vms_before_state_switch = director.vms
    vm_before_with_index_0 = vms_before_state_switch.find{ |vm| vm.index == '0'}
    vm_before_with_index_1 = vms_before_state_switch.find{ |vm| vm.index == '1'}

    bosh_runner.run("vm resurrection #{vm_before_with_index_0.job_name} #{vm_before_with_index_0.index} disable")
    bosh_runner.run("vm resurrection #{vm_before_with_index_1.job_name} #{vm_before_with_index_1.instance_uuid} disable")

    vms_after_state_switch = director.vms
    vm_after_with_index_0 = vms_after_state_switch.find{ |vm| vm.index == '0'}
    vm_after_with_index_1 = vms_after_state_switch.find{ |vm| vm.index == '1'}
    vm_after_with_index_2 = vms_after_state_switch.find{ |vm| vm.index == '2'}

    expect(vm_after_with_index_0.resurrection).to eq('paused')
    expect(vm_after_with_index_1.resurrection).to eq('paused')
    expect(vm_after_with_index_2.resurrection).to eq('active')
  end
end
