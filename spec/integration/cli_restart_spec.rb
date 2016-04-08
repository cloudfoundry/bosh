require 'spec_helper'

describe 'restart job', type: :integration do
  with_reset_sandbox_before_each

  it 'restarts a job instance / job / all jobs' do
    deploy_from_scratch

    vm_before_with_index_1 = director.vms.find{ |vm| vm.index == '1'}
    instance_uuid = vm_before_with_index_1.instance_uuid

    expect(bosh_runner.run('restart foobar 0')).to match %r{foobar/0 restarted}
    expect(bosh_runner.run("restart foobar #{instance_uuid}")).to include("foobar/#{instance_uuid} restarted")
    expect(bosh_runner.run('restart foobar')).to match %r{foobar/\* restarted}
    expect(bosh_runner.run('restart')).to match %r{all jobs restarted}
  end
end
