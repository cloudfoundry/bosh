require_relative '../spec_helper'

describe 'recreate instance', type: :integration do
  with_reset_sandbox_before_each

  it 'recreates an instance only when using index with the original config' do
    deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
    upload_cloud_config(cloud_config_hash: {})

    initial_instances = director.instances
    instance_to_be_recreated = director.find_instance(initial_instances, 'foobar', '0')
    expect(bosh_runner.run('recreate foobar/0', deployment_name: 'simple')).to match /Updating instance foobar: foobar.* \(0\)/

    instances_after_instance_recreate = director.instances
    instance_was_recreated = director.find_instance(instances_after_instance_recreate, 'foobar', '0')
    expect(instance_to_be_recreated.vm_cid).not_to eq(instance_was_recreated.vm_cid)
    expect((initial_instances-[instance_to_be_recreated]).map(&:vm_cid)).to match_array((instances_after_instance_recreate-[instance_was_recreated]).map(&:vm_cid))
  end

  it 'recreates an instance only when using instance uuid with the original config' do
    deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
    upload_cloud_config(cloud_config_hash: {})

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
      {'id' => /[0-9]{1,3} <- [0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'update', 'object_type' => 'deployment', 'task_id' => /[0-9]{1,3}/, 'object_name' => 'simple', 'deployment' => 'simple', 'instance' => '', 'context' => "after:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1\nbefore:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1", 'error' => ''},
      {'id' => /[0-9]{1,3} <- [0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'recreate', 'object_type' => 'instance', 'task_id' => /[0-9]{1,3}/, 'object_name' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'id' => /[0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'recreate', 'object_type' => 'instance', 'task_id' => /[0-9]{1,3}/, 'object_name' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'id' => /[0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'update', 'object_type' => 'deployment', 'task_id' => /[0-9]{1,3}/, 'object_name' => 'simple', 'deployment' => 'simple', 'instance' => '', 'context' => '', 'error' => ''}
    )
  end

  it 'recreates vms for a given instance group or the whole deployment with the original config' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups']<< {
        'name' => 'another-job',
        'jobs' => [{'name' => 'foobar'}],
        'vm_type' => 'a',
        'instances' => 1,
        'networks' => [{'name' => 'a'}],
        'stemcell' => 'default'
    }
    manifest_hash['instance_groups'].first['instances']= 2
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
    upload_cloud_config(cloud_config_hash: {})

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

  context 'when a new release is uploaded and the release version in the manifest is latest' do
    it 'recreates an instance with initially resolved release version' do
      release_filename = spec_asset('unsorted-release-0+dev.1.tgz')
      stemcell_filename = spec_asset('valid_stemcell.tgz')
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['releases'] = [{
        'name' => 'unsorted-release',
        'version' => 'latest'
      }]

      deployment_manifest = yaml_file('simple', manifest_hash)
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::NewDeployments.simple_cloud_config)

      bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("upload-stemcell #{stemcell_filename}")
      bosh_runner.run("upload-release #{release_filename}")

      bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')
      bosh_runner.run("upload-release #{spec_asset('unsorted-release-0+dev.2.tgz')}")
      bosh_runner.run('recreate', deployment_name: 'simple')

      table_output = table(bosh_runner.run('releases', json: true))
      expect(table_output).to include(
        {"commit_hash" => String, "name" => "unsorted-release", "version" => "0+dev.2"},
        {"commit_hash" => String, "name" => "unsorted-release", "version" => "0+dev.1*"}
      )
    end
  end

  context 'with dry run flag' do
    context 'when a vm has been deleted' do
      it 'does not try to recreate that vm' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

        vm_cid = director.vms.first.cid
        prior_vms = director.vms.length

        bosh_runner.run("delete-vm #{vm_cid}", deployment_name: 'simple')
        bosh_runner.run('recreate --dry-run foobar', deployment_name: 'simple')

        expect(director.vms.length).to be < prior_vms
      end
    end

    context 'when there are no errors' do
      it 'returns some encouraging message but does not recreate vms' do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

        initial_instances = director.instances
        bosh_runner.run('recreate --dry-run foobar', deployment_name: 'simple')
        instances_after_job_recreate = director.instances

        expect(director.find_instance(initial_instances, 'foobar', '0').vm_cid).to eq(director.find_instance(instances_after_job_recreate, 'foobar', '0').vm_cid)
        expect(director.find_instance(initial_instances, 'foobar', '1').vm_cid).to eq(director.find_instance(instances_after_job_recreate, 'foobar', '1').vm_cid)
      end
    end
  end
end
