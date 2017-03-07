require_relative '../spec_helper'

describe 'recreate instance', type: :integration do
  with_reset_sandbox_before_each

  it 'recreates an instance only when using index' do
    deploy_from_scratch

    initial_instances = director.instances
    instance_to_be_recreated = director.find_instance(initial_instances, 'foobar', '0')
    expect(bosh_runner.run('recreate foobar/0', deployment_name: 'simple')).to match /Updating instance foobar: foobar.* \(0\)/

    instances_after_instance_recreate = director.instances
    instance_was_recreated = director.find_instance(instances_after_instance_recreate, 'foobar', '0')
    expect(instance_to_be_recreated.vm_cid).not_to eq(instance_was_recreated.vm_cid)
    expect((initial_instances-[instance_to_be_recreated]).map(&:vm_cid)).to match_array((instances_after_instance_recreate-[instance_was_recreated]).map(&:vm_cid))
  end

  it 'recreates an instance only when using instance uuid' do
    deploy_from_scratch

    initial_instances = director.instances
    instance_to_be_recreated = director.find_instance(initial_instances, 'foobar', '0')
    instance_uuid = instance_to_be_recreated.id
    expect(bosh_runner.run("recreate foobar/#{instance_uuid}", deployment_name: 'simple')).to include("Updating instance foobar: foobar/#{instance_uuid}")

    instances_after_instance_recreate = director.instances
    instance_was_recreated = director.find_instance(instances_after_instance_recreate, 'foobar', '0')
    expect(instance_to_be_recreated.vm_cid).not_to eq(instance_was_recreated.vm_cid)
    expect((initial_instances-[instance_to_be_recreated]).map(&:vm_cid)).to match_array((instances_after_instance_recreate-[instance_was_recreated]).map(&:vm_cid))

    output = bosh_runner.run('events', deployment_name: 'simple', json: true)

    events = scrub_event_time(scrub_random_cids(scrub_random_ids(table(output))))
    expect(events).to include(
      {'id' => /[0-9]{1,3} <- [0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'update', 'object_type' => 'deployment', 'task_id' => /[0-9]{1,3}/, 'object_id' => 'simple', 'deployment' => 'simple', 'instance' => '', 'context' => "after:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1\nbefore:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1", 'error' => ''},
      {'id' => /[0-9]{1,3} <- [0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'recreate', 'object_type' => 'instance', 'task_id' => /[0-9]{1,3}/, 'object_id' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'id' => /[0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'recreate', 'object_type' => 'instance', 'task_id' => /[0-9]{1,3}/, 'object_id' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'id' => /[0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'update', 'object_type' => 'deployment', 'task_id' => /[0-9]{1,3}/, 'object_id' => 'simple', 'deployment' => 'simple', 'instance' => '', 'context' => '', 'error' => ''}
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
    initial_instances = director.instances
    output = bosh_runner.run('recreate foobar', deployment_name: 'simple')
    expect(output).to match /Updating instance foobar: foobar.* \(0\)/
    expect(output).to match /Updating instance foobar: foobar.* \(1\)/
    instances_after_job_recreate = director.instances
    expect(director.find_instance(initial_instances, 'foobar', '0').vm_cid).not_to eq(director.find_instance(instances_after_job_recreate, 'foobar', '0').vm_cid)
    expect(director.find_instance(initial_instances, 'foobar', '1').vm_cid).not_to eq(director.find_instance(instances_after_job_recreate, 'foobar', '1').vm_cid)
    expect(director.find_instance(initial_instances, 'another-job', '0').vm_cid).to eq(director.find_instance(instances_after_job_recreate, 'another-job', '0').vm_cid)

    #all vms should be recreated
    initial_instances = instances_after_job_recreate
    output = bosh_runner.run('recreate', deployment_name: 'simple')
    expect(output).to match /Updating instance foobar: foobar.* \(0\)/
    expect(output).to match /Updating instance foobar: foobar.* \(1\)/
    expect(output).to match /Updating instance another-job: another-job.* \(0\)/
    expect(director.instances).not_to match_array(initial_instances.map(&:vm_cid))
  end

  context 'with dry run flag' do
    context 'when a vm has been deleted' do
      it 'does not try to recreate that vm' do
        manifest_hash = Bosh::Spec::Deployments.simple_manifest

        deploy_from_scratch(manifest_hash: manifest_hash)

        vm_cid = director.vms.first.cid
        prior_vms = director.vms.length

        bosh_runner.run("delete-vm #{vm_cid}", deployment_name: 'simple')
        bosh_runner.run('recreate --dry-run foobar', deployment_name: 'simple')

        expect(director.vms.length).to be < prior_vms
      end
    end

    context 'when there are no errors' do
      it 'returns some encouraging message but does not recreate vms' do
        manifest_hash = Bosh::Spec::Deployments.simple_manifest

        deploy_from_scratch(manifest_hash: manifest_hash)

        initial_instances = director.instances
        bosh_runner.run('recreate --dry-run foobar', deployment_name: 'simple')
        instances_after_job_recreate = director.instances

        expect(director.find_instance(initial_instances, 'foobar', '0').vm_cid).to eq(director.find_instance(instances_after_job_recreate, 'foobar', '0').vm_cid)
        expect(director.find_instance(initial_instances, 'foobar', '1').vm_cid).to eq(director.find_instance(instances_after_job_recreate, 'foobar', '1').vm_cid)
      end
    end
  end
end
