require_relative '../spec_helper'

describe 'restart job', type: :integration do
  with_reset_sandbox_before_each

  let(:manifest_hash) {
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'] << {
        'name' => 'another-job',
        'jobs' => [{'name' => 'foobar'}],
        'vm_type' => 'a',
        'instances' => 1,
        'networks' => [{'name' => 'a'}],
        'stemcell' => 'default',
    }
    manifest_hash['instance_groups'].first['instances'] = 2
    manifest_hash
  }

  it 'restarts a job instance / job / all jobs' do
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

    instance_before_with_index_1 = director.instances.find{ |instance| instance.index == '1' }
    instance_uuid = instance_before_with_index_1.id

    expect(bosh_runner.run('restart foobar/0', deployment_name: 'simple')).to match /Updating instance foobar: foobar.* \(0\)/
    expect(bosh_runner.run("restart foobar/#{instance_uuid}", deployment_name: 'simple')).to match /Updating instance foobar: foobar\/#{instance_uuid} \(\d\)/
    output = bosh_runner.run('restart foobar', deployment_name: 'simple')
    expect(output).to match /Updating instance foobar: foobar\/.* \(0\)/
    expect(output).to match /Updating instance foobar: foobar\/.* \(1\)/
    output = bosh_runner.run('restart', deployment_name: 'simple')
    expect(output).to match /Updating instance foobar: foobar\/.* \(0\)/
    expect(output).to match /Updating instance foobar: foobar\/.* \(1\)/
    expect(output).to match /Updating instance another-job: another-job\/.* \(0\)/

    output = bosh_runner.run('events', json: true)
    events = scrub_event_time(scrub_random_cids(scrub_random_ids(table(output))))
    expect(events).to include(
      {'id' => /[0-9]{1,3} <- [0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'update', 'object_type' => 'deployment', 'task_id' => /[0-9]{1,3}/, 'object_name' => 'simple', 'deployment' => 'simple', 'instance' => '', 'context' => "after:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1\nbefore:\n  releases:\n  - bosh-release/0+dev.1\n  stemcells:\n  - ubuntu-stemcell/1", 'error' => ''},
      {'id' => /[0-9]{1,3} <- [0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'restart', 'object_type' => 'instance', 'task_id' => /[0-9]{1,3}/, 'object_name' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'id' => /[0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'restart', 'object_type' => 'instance', 'task_id' => /[0-9]{1,3}/, 'object_name' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => '', 'error' => ''},
      {'id' => /[0-9]{1,3}/, 'time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'user' => 'test', 'action' => 'update', 'object_type' => 'deployment', 'task_id' => /[0-9]{1,3}/, 'object_name' => 'simple', 'deployment' => 'simple', 'instance' => '', 'context' => '', 'error' => ''}
    )
  end
end
