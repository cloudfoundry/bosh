require 'spec_helper'

describe 'recreate job', type: :integration do
  with_reset_sandbox_before_each

  def vm_cid(instance_name)
    director.vms.find { |vm| vm.job_name_index == instance_name }.cid
  end

  it 'recreates a job' do
    deploy_from_scratch
    old_first_vm_cid = vm_cid('foobar/0')
    old_second_vm_cid = vm_cid('foobar/1')

    expect(bosh_runner.run('recreate foobar 0')).to match %r{foobar/0 has been recreated}
    expect(vm_cid('foobar/0')).to_not eq(old_first_vm_cid)
    expect(vm_cid('foobar/1')).to eq(old_second_vm_cid)

    expect(bosh_runner.run('recreate foobar 1')).to match %r{foobar/1 has been recreated}
    expect(vm_cid('foobar/1')).to_not eq(old_second_vm_cid)
  end

  it 'recreates a deployment' do
    deploy_from_scratch
    old_first_vm_cid = vm_cid('foobar/0')
    old_second_vm_cid = vm_cid('foobar/1')

    bosh_runner.run('deploy --recreate')
    expect(vm_cid('foobar/0')).to_not eq(old_first_vm_cid)
    expect(vm_cid('foobar/1')).to_not eq(old_second_vm_cid)
  end
end
