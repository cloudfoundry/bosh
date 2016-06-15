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

    output = bosh_runner.run('events')
    parser = Support::TableHelpers::Parser.new(scrub_event_time(scrub_random_cids(scrub_random_ids(output))))
    expect(parser.data).to include(
      {'ID' => /[0-9]{1,3} <- [0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'update', 'Object type' => 'deployment', 'Task' => /[0-9]{1,3}/, 'Object ID' => 'simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => 'before: {"releases"=>["bosh-release/0+dev.1"], "stemcells"=>["ubuntu-stemcell/1"]},'},
      {'ID' => '', 'Time' => '', 'User' => '', 'Action' => '', 'Object type' => '', 'Task' => '', 'Object ID' => '', 'Dep' => '', 'Inst' => '', 'Context' => 'after: {"releases"=>["bosh-release/0+dev.1"], "stemcells"=>["ubuntu-stemcell/1"]}'},
      {'ID' => /[0-9]{1,3} <- [0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'restart', 'Object type' => 'instance', 'Task' => /[0-9]{1,3}/, 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'ID' => /[0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'restart', 'Object type' => 'instance', 'Task' => /[0-9]{1,3}/, 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'ID' => /[0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'update', 'Object type' => 'deployment', 'Task' => /[0-9]{1,3}/, 'Object ID' => 'simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
    )
  end
end
