require 'spec_helper'

describe 'recreate job', type: :integration do
  with_reset_sandbox_before_each

  it 'recreates a job instance only' do
    deploy_from_scratch
    initial_vms = director.vms
    expect(bosh_runner.run('recreate foobar 0')).to match %r{foobar/0 recreated}

    vms_after_instance_recreate = director.vms
    vm_to_be_recreated = vm(initial_vms, "foobar/0")
    vm_was_recreated = vm(vms_after_instance_recreate, "foobar/0")
    expect(vm_to_be_recreated.cid).not_to eq(vm_was_recreated.cid)
    expect((initial_vms-[vm_to_be_recreated]).map(&:cid)).to match_array((vms_after_instance_recreate-[vm_was_recreated]).map(&:cid))
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
    expect(vm(initial_vms, "foobar/0").cid).not_to eq(vm(vms_after_job_recreate, "foobar/0").cid)
    expect(vm(initial_vms, "foobar/1").cid).not_to eq(vm(vms_after_job_recreate, "foobar/1").cid)
    expect(vm(initial_vms, "another-job/0").cid).to eq(vm(vms_after_job_recreate, "another-job/0").cid)

    #all vms should be recreated
    initial_vms = vms_after_job_recreate
    expect(bosh_runner.run('recreate')).to match %r{all jobs recreated}
    expect(director.vms).not_to match_array(initial_vms.map(&:cid))
  end


  def vm(vms, job_name_index)
    vm = vms.detect { |vm| vm.job_name_index == job_name_index }
    vm || raise("Failed to find vm #{job_name_index}")
  end
end
