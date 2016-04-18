require 'spec_helper'

describe 'recreate job', type: :integration do
  with_reset_sandbox_before_each

  it 'recreates a job instance only when using index' do
    deploy_from_scratch

    initial_vms = director.vms
    vm_to_be_recreated = director.find_vm(initial_vms, 'foobar', '0')
    expect(bosh_runner.run('recreate foobar 0')).to match %r{foobar/0 recreated}

    vms_after_instance_recreate = director.vms
    vm_was_recreated = director.find_vm(vms_after_instance_recreate, 'foobar', '0')
    expect(vm_to_be_recreated.cid).not_to eq(vm_was_recreated.cid)
    expect((initial_vms-[vm_to_be_recreated]).map(&:cid)).to match_array((vms_after_instance_recreate-[vm_was_recreated]).map(&:cid))
  end

  it 'recreates a job instance only when using instance uuid' do
    deploy_from_scratch

    initial_vms = director.vms
    vm_to_be_recreated = director.find_vm(initial_vms, 'foobar', '0')
    instance_uuid = vm_to_be_recreated.instance_uuid
    expect(bosh_runner.run("recreate foobar #{instance_uuid}")).to include ("foobar/#{instance_uuid} recreated")

    vms_after_instance_recreate = director.vms
    vm_was_recreated = director.find_vm(vms_after_instance_recreate, 'foobar', '0')
    expect(vm_to_be_recreated.cid).not_to eq(vm_was_recreated.cid)
    expect((initial_vms-[vm_to_be_recreated]).map(&:cid)).to match_array((vms_after_instance_recreate-[vm_was_recreated]).map(&:cid))

    output = bosh_runner.run('events')

    parser = Support::TableHelpers::Parser.new(scrub_event_time(scrub_random_cids(scrub_random_ids(output))))
    expect(parser.data).to include(
      {'ID' => /[0-9]{1,3} <- [0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'update', 'Object type' => 'deployment', 'Task' => /[0-9]{1,3}/, 'Object ID' => 'simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
      {'ID' => /[0-9]{1,3} <- [0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'recreate', 'Object type' => 'instance', 'Task' => /[0-9]{1,3}/, 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'ID' => /[0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'recreate', 'Object type' => 'instance', 'Task' => /[0-9]{1,3}/, 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
      {'ID' => /[0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'update', 'Object type' => 'deployment', 'Task' => /[0-9]{1,3}/, 'Object ID' => 'simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'},
)
  end

  it 'recreates vms for a given job / the whole deployment' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs']<< {
        'name' => 'another-job',
        'template' => 'foobar',
        'resource_pool' => 'a',
        'instances' => 1,
        'networks' => [{'name' => 'a'}],
    }
    manifest_hash['jobs'].first['instances']= 2
    deploy_from_scratch(manifest_hash: manifest_hash)

    #only vms for one job should be recreated
    initial_vms = director.vms
    expect(bosh_runner.run('recreate foobar')).to match %r{foobar/\* recreated}
    vms_after_job_recreate = director.vms
    expect(director.find_vm(initial_vms, 'foobar', '0').cid).not_to eq(director.find_vm(vms_after_job_recreate, 'foobar', '0').cid)
    expect(director.find_vm(initial_vms, 'foobar', '1').cid).not_to eq(director.find_vm(vms_after_job_recreate, 'foobar', '1').cid)
    expect(director.find_vm(initial_vms, 'another-job', '0').cid).to eq(director.find_vm(vms_after_job_recreate, 'another-job', '0').cid)

    #all vms should be recreated
    initial_vms = vms_after_job_recreate
    expect(bosh_runner.run('recreate')).to match %r{all jobs recreated}
    expect(director.vms).not_to match_array(initial_vms.map(&:cid))
  end
end
