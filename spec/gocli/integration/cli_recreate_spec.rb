require_relative '../spec_helper'

describe 'recreate instance', type: :integration do
  with_reset_sandbox_before_each

  it 'recreates an instance only when using index' do
    deploy_from_scratch

    initial_vms = director.vms
    vm_to_be_recreated = director.find_vm(initial_vms, 'foobar', '0')
    expect(bosh_runner.run('recreate foobar/0', deployment_name: 'simple')).to match /Updating instance foobar: foobar.* \(0\)/

    vms_after_instance_recreate = director.vms
    vm_was_recreated = director.find_vm(vms_after_instance_recreate, 'foobar', '0')
    expect(vm_to_be_recreated.cid).not_to eq(vm_was_recreated.cid)
    expect((initial_vms-[vm_to_be_recreated]).map(&:cid)).to match_array((vms_after_instance_recreate-[vm_was_recreated]).map(&:cid))
  end

  it 'recreates an instance only when using instance uuid' do
    deploy_from_scratch

    initial_vms = director.vms
    vm_to_be_recreated = director.find_vm(initial_vms, 'foobar', '0')
    instance_uuid = vm_to_be_recreated.instance_uuid
    expect(bosh_runner.run("recreate foobar/#{instance_uuid}", deployment_name: 'simple')).to include("Updating instance foobar: foobar/#{instance_uuid}")

    vms_after_instance_recreate = director.vms
    vm_was_recreated = director.find_vm(vms_after_instance_recreate, 'foobar', '0')
    expect(vm_to_be_recreated.cid).not_to eq(vm_was_recreated.cid)
    expect((initial_vms-[vm_to_be_recreated]).map(&:cid)).to match_array((vms_after_instance_recreate-[vm_was_recreated]).map(&:cid))

    output = bosh_runner.run('events', deployment_name: 'simple', json: true)

    events = scrub_event_time(scrub_random_cids(scrub_random_ids(table(output))))
    expect(events).to include(
      {'ID' => /[0-9]{1,3} <- [0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'update', 'Object Type' => 'deployment', 'Task ID' => /[0-9]{1,3}/, 'Object ID' => 'simple', 'Deployment' => 'simple', 'Instance' => '', 'Context' => "after:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1\nbefore:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1"},
      {'ID' => /[0-9]{1,3} <- [0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'recreate', 'Object Type' => 'instance', 'Task ID' => /[0-9]{1,3}/, 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => ''},
      {'ID' => /[0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'recreate', 'Object Type' => 'instance', 'Task ID' => /[0-9]{1,3}/, 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => ''},
      {'ID' => /[0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'update', 'Object Type' => 'deployment', 'Task ID' => /[0-9]{1,3}/, 'Object ID' => 'simple', 'Deployment' => 'simple', 'Instance' => '', 'Context' => ''}
    )
  end

  it 'recreates vms for a given instance group or the whole deployment' do
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
    output = bosh_runner.run('recreate foobar', deployment_name: 'simple')
    expect(output).to match /Updating instance foobar: foobar.* \(0\)/
    expect(output).to match /Updating instance foobar: foobar.* \(1\)/
    vms_after_job_recreate = director.vms
    expect(director.find_vm(initial_vms, 'foobar', '0').cid).not_to eq(director.find_vm(vms_after_job_recreate, 'foobar', '0').cid)
    expect(director.find_vm(initial_vms, 'foobar', '1').cid).not_to eq(director.find_vm(vms_after_job_recreate, 'foobar', '1').cid)
    expect(director.find_vm(initial_vms, 'another-job', '0').cid).to eq(director.find_vm(vms_after_job_recreate, 'another-job', '0').cid)

    #all vms should be recreated
    initial_vms = vms_after_job_recreate
    output = bosh_runner.run('recreate', deployment_name: 'simple')
    expect(output).to match /Updating instance foobar: foobar.* \(0\)/
    expect(output).to match /Updating instance foobar: foobar.* \(1\)/
    expect(output).to match /Updating instance another-job: another-job.* \(0\)/
    expect(director.vms).not_to match_array(initial_vms.map(&:cid))
  end

  context 'with dry run flag' do
    context 'when a vm has been deleted' do
      it 'does not try to recreate that vm' do
        manifest_hash = Bosh::Spec::Deployments.simple_manifest

        deploy_from_scratch(manifest_hash: manifest_hash)

        vm_cid = director.vms.first.cid
        prior_vms = director.vms.length

        bosh_runner.run("delete-vm #{vm_cid}", deployment_name: 'simple')
        output = bosh_runner.run('recreate --dry-run foobar', deployment_name: 'simple')

        expect(director.vms.length).to be < prior_vms
      end
    end

    context 'when there are no errors' do
      it 'returns some encouraging message but does not recreate vms' do
        manifest_hash = Bosh::Spec::Deployments.simple_manifest

        deploy_from_scratch(manifest_hash: manifest_hash)

        initial_vms = director.vms
        bosh_runner.run('recreate --dry-run foobar', deployment_name: 'simple')
        vms_after_job_recreate = director.vms

        expect(director.find_vm(initial_vms, 'foobar', '0').cid).to eq(director.find_vm(vms_after_job_recreate, 'foobar', '0').cid)
        expect(director.find_vm(initial_vms, 'foobar', '1').cid).to eq(director.find_vm(vms_after_job_recreate, 'foobar', '1').cid)
      end
    end
  end
end
